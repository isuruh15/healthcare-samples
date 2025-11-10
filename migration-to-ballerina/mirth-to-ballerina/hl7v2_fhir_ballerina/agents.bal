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

// Pipeline agents (processors) using xlibb/pipeline
// These replace Mirth's transformers, filters, and destinations

import ballerina/log;
import ballerina/messaging;
import xlibb/pipeline;
import ballerinax/rabbitmq;

# RabbitMQ queue to store the failed orders.
final rabbitmq:MessageStore failureStore = check new("order-failure-store");

// Transformer: Parse incoming HL7 message
// Equivalent to Mirth's Source Transformer with MapperSteps
@pipeline:TransformerConfig {id: "parseHl7Message"}
isolated function parseHl7MessageTransformer(pipeline:MessageContext context) returns json|error {
    log:printDebug("Transformer: Parsing HL7 message", messageId = context.getId());

    // Get raw HL7 message from context
    string rawMessage = check context.getContentWithType();
    string messageId = context.getId();

    // Parse HL7 message
    Hl7Message hl7Message = check parseHl7Message(rawMessage, messageId);

    // Store in context properties (like Mirth's channel map)
    context.setProperty("Message code", hl7Message.header.messageCode);
    context.setProperty("Message Trigger Event", hl7Message.header.triggerEvent);
    context.setProperty("First Name", hl7Message.patient.firstName);
    context.setProperty("Last Name", hl7Message.patient.lastName);
    context.setProperty("Date Of Birth", hl7Message.patient.dateOfBirth);
    context.setProperty("hl7Message", hl7Message);

    log:printInfo("Parsed HL7 message",
        messageId = messageId,
        messageCode = hl7Message.header.messageCode,
        triggerEvent = hl7Message.header.triggerEvent,
        patientName = string `${hl7Message.patient.lastName}, ${hl7Message.patient.firstName}`
    );

    // Return hl7Message as content for next processor
    return hl7Message.toJson();
}

// Transformer: Convert HL7 to JSON
// Equivalent to Mirth's JavaScript transformer "Conversion"
@pipeline:TransformerConfig {id: "convertToJson"}
isolated function convertToJsonTransformer(pipeline:MessageContext context) returns json|error {
    log:printDebug("Transformer: Converting to JSON", messageId = context.getId());

    // Retrieve HL7 message from context
    anydata hl7MessageData = context.getProperty("hl7Message");
    if hl7MessageData is () {
        return error("HL7 message not found in context");
    }

    Hl7Message hl7Message = check hl7MessageData.ensureType();

    // Transform to JSON format with date conversion
    PatientJsonData jsonData = check transformToJson(hl7Message);

    // Store in context (like Mirth's channelMap.put('hl7_json_object', hl7JsonObject))
    context.setProperty("hl7_json_object", jsonData);
    context.setProperty("jsonData", jsonData);

    log:printInfo("Converted to JSON",
        messageId = context.getId(),
        jsonObject = jsonData.toString()
    );

    // Return jsonData as content for next processor
    return jsonData.toJson();
}

// Processor: Validate patient data
// Equivalent to Mirth's "Fields Validation" destination
@pipeline:ProcessorConfig {id: "validatePatientData"}
isolated function validatePatientDataProcessor(pipeline:MessageContext context) returns error? {
    log:printDebug("Processor: Validating patient data", messageId = context.getId());

    // Retrieve data from context
    anydata hl7MessageData = context.getProperty("hl7Message");
    anydata jsonDataValue = context.getProperty("jsonData");

    if hl7MessageData is () || jsonDataValue is () {
        return error("Required data not found in context");
    }

    Hl7Message hl7Message = check hl7MessageData.ensureType();
    PatientJsonData jsonData = check jsonDataValue.ensureType();

    // Validate patient data
    ValidationResult validation = validatePatientData(jsonData, hl7Message);

    // Store validation result in context
    context.setProperty("validationResult", validation);

    // Log validation results (equivalent to Mirth's logger.info)
    logValidationResult(context.getId(), validation, jsonData);

    // Log JSON object in plain text (equivalent to Mirth's logger.info)
    log:printInfo("JSON object in plain text",
        messageId = context.getId(),
        jsonObject = jsonData.toString()
    );

    // If validation fails, log warning but don't stop processing
    // (Original Mirth channel doesn't stop on validation failure)
    if !validation.isValid {
        log:printWarn("Validation failed but continuing processing",
            messageId = context.getId(),
            fullNameError = validation.fullNameError,
            dobError = validation.dobError
        );
    }

    return;
}

// Destination: Insert to database (disabled by default)
// Equivalent to Mirth's "MySQL insert query" destination
@pipeline:DestinationConfig {
    id: "insertToDatabase",
    retryConfig: {
        maxRetries: 3,
        retryInterval: 2
    }
}
isolated function insertToDatabaseDestination(pipeline:MessageContext context) returns error? {
    log:printDebug("Destination: Inserting to database", messageId = context.getId());

    if !appConfig.database.enabled {
        log:printDebug("Database destination is disabled. Skipping insert.", messageId = context.getId());
        return;
    }

    // Retrieve data from context
    anydata hl7MessageData = context.getProperty("hl7Message");
    anydata jsonDataValue = context.getProperty("jsonData");

    if hl7MessageData is () || jsonDataValue is () {
        return error("Required data not found in context");
    }

    Hl7Message hl7Message = check hl7MessageData.ensureType();
    PatientJsonData jsonData = check jsonDataValue.ensureType();

    // Convert to database record
    PatientDatabaseRecord dbRecord = toDatabaseRecord(hl7Message, jsonData);

    // Insert to database
    check insertPatientToDatabase(dbRecord);

    log:printInfo("Inserted to database",
        messageId = context.getId(),
        patient = dbRecord.toString()
    );

    return;
}

// Simple in-memory failure store implementation
// For production, use RabbitMQ-based store
isolated service class SimpleFailureStore {
    *messaging:Store;

    private map<messaging:Message> messages = {};
    private string[] messageIds = [];

    remote isolated function store(anydata message) returns error? {
        // Store failed messages with a generated ID
        string messageId = generateMessageId();
        messaging:Message msg = {
            id: messageId,
            payload: message};
        lock {
            self.messages[messageId] = msg.clone();
            self.messageIds.push(messageId);
        }
        log:printWarn("Message stored in failure store", messageId = messageId);
        return;
    }

    remote isolated function retrieve() returns messaging:Message|error? {
        lock {
            if self.messageIds.length() > 0 {
                string messageId = self.messageIds[0];
                if self.messages.hasKey(messageId) {
                    messaging:Message message = self.messages.get(messageId);
                    return message.clone();
                }
            }
        }
        return ();
    }

    remote isolated function acknowledge(string messageId, boolean positiveAck) returns error? {
        lock {
            if self.messages.hasKey(messageId) {
                _ = self.messages.remove(messageId);
                // Remove from messageIds array
                int? index = self.messageIds.indexOf(messageId);
                if index is int {
                    _ = self.messageIds.remove(index);
                }
                log:printInfo("Message acknowledged and removed from failure store",
                    messageId = messageId,
                    positiveAck = positiveAck
                );
                return;
            }
        }
        return error(string `Message not found: ${messageId}`);
    }
}

// Create and configure the handler chain
// This is the equivalent of the entire Mirth channel pipeline
public function createHandlerChain() returns pipeline:HandlerChain|error {
    log:printInfo("Creating handler chain", name = appConfig.pipeline.name);

    // Create failure store
    // Note: For production, implement with RabbitMQ: rabbitmq:MessageStore
    // For now, we create a simple in-memory failure store
    // SimpleFailureStore failureStore = new();

    // Create handler chain with processors and destinations
    pipeline:HandlerChain handlerChain = check new (
        name = appConfig.pipeline.name,
        processors = [
            parseHl7MessageTransformer, // Parse HL7
            convertToJsonTransformer, // Convert to JSON
            validatePatientDataProcessor // Validate data
        ],
        destinations = [
            insertToDatabaseDestination // Insert to DB (if enabled)
        ],
        failureStore = failureStore
    );

    log:printInfo("Handler chain created successfully",
        name = appConfig.pipeline.name,
        processorsCount = 3,
        destinationsCount = 1
    );

    return handlerChain;
}
