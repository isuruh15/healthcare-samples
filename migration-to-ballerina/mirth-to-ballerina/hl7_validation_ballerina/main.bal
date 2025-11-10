import ballerina/tcp;
import ballerina/log;
import ballerina/lang.runtime;
import ballerinax/health.hl7v2;

# TCP connection service for handling HL7 messages
service class Hl7ConnectionService {
    *tcp:ConnectionService;
    
    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {
        do {
            // Extract HL7 message from MLLP framing
            string hl7Message = check extractMllpMessage(data);
            log:printInfo("Received HL7 message", messageLength = hl7Message.length());
            
            // Process message through pipeline
            _ = start processHl7Message(hl7Message, caller);
            
        } on fail var e {
            log:printError("Error processing HL7 message", 'error = e);
            
            // Send NACK response
            string nackResponse = generateHl7Response("", AE, e.message());
            byte[] nackBytes = createMllpResponse(nackResponse);
            tcp:Error? writeResult = caller->writeBytes(nackBytes);
            
            if writeResult is tcp:Error {
                log:printError("Failed to send NACK response", 'error = writeResult);
            }
        }
    }
    
    remote function onError(tcp:Error err) {
        log:printError("TCP connection error", 'error = err);
    }
    
    remote function onClose() {
        log:printInfo("HL7 connection closed");
    }
}

# Process HL7 message through pipeline
isolated function processHl7Message(string hl7Message, tcp:Caller caller) returns error? {
    do {
        hl7v2:Message hl7Msg = check hl7v2:parse(hl7Message);
        // Execute pipeline processing
        any result = check hl7ProcessingPipeline.execute(hl7Msg);
        
        // Send ACK response
        string ackResponse = generateHl7Response(hl7Message, AA);
        byte[] ackBytes = createMllpResponse(ackResponse);
        tcp:Error? writeResult = caller->writeBytes(ackBytes);
        
        if writeResult is tcp:Error {
            log:printError("Failed to send ACK response", 'error = writeResult);
        } else {
            log:printInfo("Successfully processed HL7 message and sent ACK");
        }
        
    } on fail var e {
        log:printError("Pipeline processing failed", 'error = e);
        
        // Send application error response
        string errorResponse = generateHl7Response(hl7Message, AE, e.message());
        byte[] errorBytes = createMllpResponse(errorResponse);
        tcp:Error? writeResult = caller->writeBytes(errorBytes);
        
        if writeResult is tcp:Error {
            log:printError("Failed to send error response", 'error = writeResult);
        }
        
        return e;
    }
}

# Main service entry point
public function main() returns error? {
    // TCP listener for HL7 messages
    tcp:Listener tcpListener = check new (
        localPort = tcpPort,
        localHost = tcpHost
    );
    
    log:printInfo("Starting HL7 TCP listener", 
        host = tcpHost, 
        port = tcpPort, 
        maxConnections = maxConnections
    );
    
    // Register connection service
    check tcpListener.attach(isolated service object {
        remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService|tcp:Error {
            log:printInfo("New HL7 client connected");
            return new Hl7ConnectionService();
        }
    });
    
    // Start listener
    check tcpListener.'start();
    log:printInfo("HL7 processing service started successfully");
    
    // Keep the service running
    runtime:sleep(999999999.0);
}

# Graceful shutdown handler
isolated function gracefulStop() returns error? {
    log:printInfo("Shutting down HL7 processing service");
    check dbClient.close();
    log:printInfo("Database connections closed");
}