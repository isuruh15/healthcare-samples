import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/health.fhir.r4;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v2.utils.v2tofhirr4;

type Hl7Message readonly & record {|
    string content;
|};

configurable int servicePort = 9090;

function init() {
    log:printInfo("HL7v2 to Danish Transformation Service Started..");
}

service /hl7 on new http:Listener(servicePort) {
    resource function post parse/danish(@http:Payload string payload) returns json|string|error {
        string incomingMessage = payload;

        // Log the incoming raw payload
        log:printInfo("Received HL7 message", rawMessage = incomingMessage);

        // Process the message considering newline characters
        string processedMessage = "";
        string[] segments = re `\r`.split(incomingMessage);
        foreach string segment in segments {
            if segment != "" {
                processedMessage = string:'join("\n", processedMessage, segment);
            }
        }

        // Log the processed message
        log:printDebug("Processed HL7 message", processedMessage = processedMessage);

        // Validate if it's a valid HL7 message, and parse
        hl7v2:Message|error parsedMessage = hl7v2:parse(incomingMessage);
        if parsedMessage is error {
            log:printError("Invalid HL7 message", 'error = parsedMessage);
            return error("Invalid HL7 message format");
        }

        json v2tofhirResult = check v2tofhirr4:v2ToFhir(parsedMessage);

        // Cast to FHIR Bundle
        r4:Bundle transformedBundle = check v2tofhirResult.cloneWithType(r4:Bundle);
        io:println("-------------------- Standard FHIR bundle --------------------");
        io:println(v2tofhirResult);

        // Converting to Danish IG resources
        //http://medcomfhir.dk/ig/core/2.4.0/
        r4:Bundle castedBundle = check processBundle(transformedBundle, parsedMessage);

        io:println("-------------------- Danish FHIR bundle --------------------");
        io:println(castedBundle);
        io:println("------------------------------------------------------------------");

        return castedBundle.toJson();
    }

}
