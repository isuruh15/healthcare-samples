// Copyright (c) 2025 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

// Main module - TCP Listener with MLLP support for HL7 v2.x messages
// Equivalent to Mirth's TCP Listener source connector

import ballerina/log;
import ballerina/tcp;
import xlibb/pipeline;

// Global handler chain instance
final pipeline:HandlerChain handlerChain = check createHandlerChain();

// TCP Listener service
// Equivalent to Mirth's TCP Listener source connector on port 6662
service on new tcp:Listener(appConfig.tcpListener.port) {

    // Called when a new connection is established
    remote function onConnect(tcp:Caller caller) returns tcp:ConnectionService {
        log:printInfo("New TCP connection established",
            remoteHost = caller.remoteHost,
            remotePort = caller.remotePort
        );

        return new Hl7ConnectionService(handlerChain, caller);
    }
}

// HL7 Connection Service - handles MLLP protocol and message processing
// This is the connection-specific service that processes incoming HL7 messages
service class Hl7ConnectionService {
    *tcp:ConnectionService;

    private final pipeline:HandlerChain handlerChain;
    private final tcp:Caller caller;
    private byte[] buffer = [];

    function init(pipeline:HandlerChain handlerChain, tcp:Caller caller) {
        self.handlerChain = handlerChain;
        self.caller = caller;
    }

    // Called when data is received on the connection
    remote function onBytes(tcp:Caller caller, readonly & byte[] data) returns tcp:Error? {
        log:printDebug("Received data",
            bytesReceived = data.length(),
            remoteHost = caller.remoteHost
        );

        // Append data to buffer
        foreach byte b in data {
            self.buffer.push(b);
        }

        // Process complete MLLP frames from buffer
        do {
	
	        // Process complete MLLP frames from buffer
	        check self.processBuffer(caller);
        } on fail var e {
            log:printError("Error processing MLLP frame",
                errorMessage = e.message()
            );
        	
        }
    }

    // Process buffer and extract complete MLLP frames
    private function processBuffer(tcp:Caller caller) returns error? {
        while true {
            // Look for complete MLLP frame: <SB>message<EB><CR>
            int? frameEnd = self.findMllpFrameEnd();

            if frameEnd is () {
                // No complete frame yet, wait for more data
                break;
            }

            // Extract frame from buffer
            byte[] frameData = [];
            int i = 0;
            while i <= frameEnd {
                frameData.push(self.buffer[i]);
                i = i + 1;
            }

            // Remove processed frame from buffer
            byte[] newBuffer = [];
            int j = frameEnd + 1;
            while j < self.buffer.length() {
                newBuffer.push(self.buffer[j]);
                j = j + 1;
            }
            self.buffer = newBuffer;

            // Process the frame
            check self.processFrame(frameData, caller);
        }
    }

    // Find the end of an MLLP frame in the buffer
    private function findMllpFrameEnd() returns int? {
        // Look for start byte (0x0B)
        int? startIndex = ();
        int i = 0;
        while i < self.buffer.length() {
            if self.buffer[i] == appConfig.mllp.startOfMessageByte {
                startIndex = i;
                break;
            }
            i = i + 1;
        }

        if startIndex is () {
            return ();
        }

        // Look for end bytes (0x1C, 0x0D) after start
        int j = startIndex + 1;
        while j < self.buffer.length() - 1 {
            if self.buffer[j] == appConfig.mllp.endOfMessageBytes[0] &&
               self.buffer[j + 1] == appConfig.mllp.endOfMessageBytes[1] {
                return j + 1; // Return index of last byte in frame
            }
            j = j + 1;
        }

        return ();
    }

    // Process a complete MLLP frame
    private function processFrame(byte[] frameData, tcp:Caller caller) returns error? {
        log:printDebug("Processing MLLP frame", frameSize = frameData.length());

        // Extract HL7 message from MLLP frame
        string hl7Message = check extractMessageFromMllp(frameData);

        log:printInfo("Received HL7 message",
            messageLength = hl7Message.length(),
            messagePreview = hl7Message.substring(0, hl7Message.length() < 100 ? hl7Message.length() : 100)
        );

        // Generate unique message ID
        string messageId = generateMessageId();

        // Process message asynchronously through pipeline
        future<anydata|pipeline:Error> result = start self.handlerChain.execute(hl7Message);

        // Wait for processing to complete
        anydata|pipeline:Error processingResult = wait result;

        // Generate and send ACK/NACK response
        check self.sendResponse(hl7Message, processingResult, caller);
    }

    // Send ACK or NACK response based on processing result
    private function sendResponse(
        string hl7Message,
        anydata|pipeline:Error processingResult,
        tcp:Caller caller
    ) returns error? {
        // Extract message control ID from message for ACK
        string|error messageControlIdResult = getHl7Field(hl7Message, "MSH", "10");
        string messageControlId = messageControlIdResult is error ? generateMessageId() : messageControlIdResult;

        if messageControlId.trim().length() == 0 {
            messageControlId = generateMessageId();
        }

        Hl7AckResponse response;

        if processingResult is pipeline:Error {
            // Processing failed - send NACK
            log:printError("Message processing failed",
                messageControlId = messageControlId,
                errorMessage = processingResult.message()
            );

            response = generateNack(messageControlId, processingResult.message());
        } else {
            // Processing succeeded - send ACK
            log:printInfo("Message processed successfully", messageControlId = messageControlId);

            response = generateAck(messageControlId, "Message processed successfully");
        }

        // Wrap ACK/NACK in MLLP frame and send
        byte[] responseData = wrapMessageInMllp(response.rawAckMessage);

        check caller->writeBytes(responseData);

        log:printInfo("Sent response",
            acknowledgeCode = response.acknowledgeCode,
            messageControlId = response.messageControlId
        );
    }

    // Called when the connection is closed
    remote function onClose() {
        log:printInfo("TCP connection closed",
            remoteHost = self.caller.remoteHost,
            remotePort = self.caller.remotePort
        );
    }

    // Called when an error occurs
    remote function onError(tcp:Error err) {
        log:printError("TCP connection error",
            remoteHost = self.caller.remoteHost,
            errorMessage = err.message()
        );
    }
}

// Application entry point
public function main() returns error? {
    log:printInfo("Starting HL7 Conversion Service",
        version = "1.0.0",
        port = appConfig.tcpListener.port,
        host = appConfig.tcpListener.host
    );

    log:printInfo("Configuration loaded",
        maxConnections = appConfig.tcpListener.maxConnections,
        bufferSize = appConfig.tcpListener.bufferSize,
        processingThreads = appConfig.hl7Processing.processingThreads,
        databaseEnabled = appConfig.database.enabled
    );

    log:printInfo("Service started successfully. Listening for HL7 messages over TCP/MLLP...");

    // Keep the service running
    // The TCP listener will handle connections automatically
}
