import ballerina/log;
import ballerina/io;
import ballerina/time;
import xlibb/pipeline;

// Pipeline-based agents using xlibb/pipeline module
// This follows the Mirth Connect channel pattern: Source -> Filter -> Transformer -> Destination

// ========================================================================================
// FILTER: Validates HL7 messages before processing
// ========================================================================================
// This filter ensures only valid HL7 v2.3 messages proceed through the pipeline
// Returns true if the message should continue, false to drop the message
@pipeline:FilterConfig {
    id: "hl7MessageFilter"
}
public isolated function filterHL7Messages(pipeline:MessageContext context) returns boolean|error {
    log:printInfo("=== FILTER: Validating HL7 message ===", messageId = context.getId());

    // Get message content from the context
    anydata rawContent = context.getContent();

    // Extract the actual HL7 content string
    string hl7Content;
    if rawContent is map<anydata> {
        // If wrapped in metadata map, extract the content field
        if rawContent.hasKey("content") {
            anydata contentData = rawContent.get("content");
            if contentData is string {
                hl7Content = contentData;

                // Also extract and store metadata in context for later use
                if rawContent.hasKey("fileName") {
                    context.setProperty("fileName", rawContent.get("fileName"));
                }
                if rawContent.hasKey("filePath") {
                    context.setProperty("filePath", rawContent.get("filePath"));
                }
            } else {
                log:printWarn("Content field is not a string, filtering out", messageId = context.getId());
                context.setProperty("filterReason", "Invalid content type");
                return false;
            }
        } else {
            log:printWarn("No content field found in message data, filtering out", messageId = context.getId());
            context.setProperty("filterReason", "Missing content field");
            return false;
        }
    } else if rawContent is string {
        hl7Content = rawContent;
    } else {
        log:printWarn("Message content is not in expected format, filtering out", messageId = context.getId());
        context.setProperty("filterReason", "Unsupported content format");
        return false;
    }

    // Validation 1: Check if the message starts with MSH segment (HL7 indicator)
    if !hl7Content.startsWith("MSH") {
        log:printWarn("Message does not start with MSH segment, filtering out",
            messageId = context.getId(),
            contentPreview = hl7Content.substring(0, hl7Content.length() < 50 ? hl7Content.length() : 50)
        );
        context.setProperty("filterReason", "Missing MSH segment");
        return false;
    }

    // Validation 2: Check minimum message length
    if hl7Content.length() < 20 {
        log:printWarn("Message too short to be valid HL7, filtering out",
            messageId = context.getId(),
            length = hl7Content.length()
        );
        context.setProperty("filterReason", "Message too short");
        return false;
    }

    // Store the extracted HL7 content in context for the next processor
    context.setProperty("hl7Content", hl7Content);

    log:printInfo("✓ FILTER: Message passed validation",
        messageId = context.getId(),
        contentLength = hl7Content.length()
    );
    return true;
}

// ========================================================================================
// TRANSFORMER: Transforms HL7 v2.3 messages to v2.4 format
// ========================================================================================
// This transformer converts HL7 v2.3 ADT messages to v2.4 format
// Returns the transformed message content that replaces the current message in the pipeline
@pipeline:TransformerConfig {
    id: "hl7V23ToV24Transformer"
}
public isolated function transformHL7Message(pipeline:MessageContext context) returns anydata|error {
    log:printInfo("=== TRANSFORMER: Converting HL7 v2.3 to v2.4 ===", messageId = context.getId());

    // Retrieve the HL7 content stored by the filter
    string hl7Content;
    if context.hasProperty("hl7Content") {
        anydata storedContent = context.getProperty("hl7Content");
        if storedContent is string {
            hl7Content = storedContent;
        } else {
            return error("HL7 content in context is not a string");
        }
    } else {
        // Fallback: try to get from the message content directly
        anydata rawContent = context.getContent();
        if rawContent is string {
            hl7Content = rawContent;
        } else if rawContent is map<anydata> && rawContent.hasKey("content") {
            anydata contentData = rawContent.get("content");
            if contentData is string {
                hl7Content = contentData;
            } else {
                return error("Invalid message content type in transformation");
            }
        } else {
            return error("Unable to extract HL7 content for transformation");
        }
    }

    log:printDebug("Parsing HL7 v2.3 message", messageId = context.getId(), contentLength = hl7Content.length());

    // Step 1: Parse HL7 v2.3 message
    anydata v23Message = check parseHL7v23(hl7Content);
    log:printDebug("✓ Successfully parsed HL7 v2.3 message", messageId = context.getId());

    // Store the parsed v2.3 message for reference
    context.setProperty("v23Message", v23Message);

    // Step 2: Transform to v2.4 format
    anydata v24Message = check transformHL7v23ToV24(v23Message);
    log:printDebug("✓ Successfully transformed message structure to v2.4", messageId = context.getId());

    // Store the parsed v2.4 message for reference
    context.setProperty("v24Message", v24Message);

    // Step 3: Serialize v2.4 message back to string
    string transformedContent = check serializeHL7v24(v24Message);
    log:printInfo("✓ TRANSFORMER: Transformation completed successfully",
        messageId = context.getId(),
        originalLength = hl7Content.length(),
        transformedLength = transformedContent.length()
    );

    // Store transformation metadata
    context.setProperty("originalContent", hl7Content);
    context.setProperty("transformationTimestamp", time:utcNow());

    // Return the transformed content - this becomes the new message content in the pipeline
    return transformedContent;
}

// ========================================================================================
// DESTINATION: Writes the transformed HL7 message to a file
// ========================================================================================
// This destination writes the final transformed message to the output directory
// Implements automatic retry on failures (configured in @DestinationConfig)
// Returns delivery status information
@pipeline:DestinationConfig {
    id: "fileDestination",
    retryConfig: {
        maxRetries: appConfig.pipeline.maxRetries,
        retryInterval: appConfig.pipeline.destinationRetryInterval
    }
}
public isolated function writeToFile(pipeline:MessageContext context) returns anydata|error {
    log:printInfo("=== DESTINATION: Writing transformed message to file ===", messageId = context.getId());

    // Get the transformed content (this is the output of the transformer)
    anydata content = context.getContent();

    if content !is string {
        string errMsg = string `Invalid message content type for file writing: ${typeof content}`;
        log:printError(errMsg, messageId = context.getId());
        return error(errMsg);
    }

    // Retrieve metadata from context (set by filter)
    string fileName = "unknown.txt";
    string filePath = "";

    if context.hasProperty("fileName") {
        anydata fileNameData = context.getProperty("fileName");
        if fileNameData is string {
            fileName = fileNameData;
        }
    }

    if context.hasProperty("filePath") {
        anydata filePathData = context.getProperty("filePath");
        if filePathData is string {
            filePath = filePathData;
        }
    }

    log:printDebug("File metadata retrieved",
        messageId = context.getId(),
        fileName = fileName,
        originalPath = filePath
    );

    // Generate output file name using the configured pattern
    // Pattern can include placeholders like ${originalFilename}, ${timestamp}, ${DATE}, ${SYSTIME}
    string outputFileName = generateOutputFileName(fileName, appConfig.destination.fileNamePattern);
    string outputPath = string `${appConfig.destination.outputDirectory}/${outputFileName}`;

    log:printDebug("Writing transformed content",
        messageId = context.getId(),
        outputPath = outputPath,
        contentLength = content.length()
    );

    // Write the transformed content to the output file
    error? writeResult = io:fileWriteString(outputPath, content);
    if writeResult is error {
        string errMsg = string `Failed to write file: ${writeResult.message()}`;
        log:printError(errMsg, messageId = context.getId(), outputPath = outputPath);
        return error(errMsg);
    }

    log:printInfo("✓ File written successfully",
        messageId = context.getId(),
        outputPath = outputPath,
        size = content.length()
    );

    // Move original file to processed directory (matching Mirth's afterProcessingAction: MOVE)
    if filePath.length() > 0 {
        string processedFilePath = string `${appConfig.destination.outputDirectory}/${fileName}`;

        log:printDebug("Moving original file",
            messageId = context.getId(),
            'from = filePath,
            to = processedFilePath
        );

        error? moveResult = moveFile(filePath, processedFilePath);

        if moveResult is error {
            // Log warning but don't fail the destination - the transformation was successful
            log:printWarn("Failed to move original file (non-critical)",
                messageId = context.getId(),
                err = moveResult.message(),
                originalPath = filePath
            );
        } else {
            log:printInfo("✓ Original file moved to processed directory",
                messageId = context.getId(),
                'from = filePath,
                to = processedFilePath
            );
        }
    }

    // Prepare delivery report
    map<anydata> deliveryReport = {
        "status": "success",
        "outputPath": outputPath,
        "outputFileName": outputFileName,
        "messageId": context.getId(),
        "originalFileName": fileName,
        "contentSize": content.length(),
        "timestamp": time:utcNow()
    };

    log:printInfo("✓ DESTINATION: Message delivered successfully",
        messageId = context.getId(),
        outputPath = outputPath
    );

    // Return the delivery report
    return deliveryReport;
}
