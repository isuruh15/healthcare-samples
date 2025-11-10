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

// Utility functions for HL7 processing, MLLP handling, and ACK generation

import ballerina/log;
import ballerina/lang.regexp;
import ballerina/time;
import ballerina/uuid;

// MLLP (Minimum Lower Layer Protocol) Functions

// Extract HL7 message from MLLP frame
// MLLP format: <SB>message<EB><CR> where SB=0x0B, EB=0x1C, CR=0x0D
public isolated function extractMessageFromMllp(byte[] data) returns string|error {
    string dataStr = check string:fromBytes(data);

    // Find start of message byte (0x0B)
    int? startIndexResult = dataStr.indexOf(string `${"\u{000B}"}`, 0);
    if startIndexResult is () {
        return error("MLLP start byte not found");
    }
    int startIndex = startIndexResult;

    // Find end of message bytes (0x1C followed by 0x0D)
    int? endIndexResult = dataStr.indexOf(string `${"\u{001C}"}${"\r"}`, startIndex);
    if endIndexResult is () {
        return error("MLLP end bytes not found");
    }
    int endIndex = endIndexResult;

    // Extract message (between start and end markers)
    string message = dataStr.substring(startIndex + 1, endIndex);
    return message;
}

// Wrap HL7 message in MLLP frame for transmission
public isolated function wrapMessageInMllp(string message) returns byte[] {
    // MLLP format: <0x0B>message<0x1C><0x0D>
    string wrappedMessage = string `${"\u{000B}"}${message}${"\u{001C}"}${"\r"}`;
    return wrappedMessage.toBytes();
}

// Date/Time Utility Functions

// Convert HL7 date format (YYYYMMDD) to ISO format (YYYY-MM-DD)
// Equivalent to Mirth's: moment(dateStr, 'YYYYMMDD').format('YYYY-MM-DD')
public isolated function convertHl7DateToIso(string hl7Date) returns string|error {
    // Validate length
    if hl7Date.length() != 8 {
        return error("Invalid HL7 date format. Expected YYYYMMDD, got: " + hl7Date);
    }

    // Extract components
    string year = hl7Date.substring(0, 4);
    string month = hl7Date.substring(4, 6);
    string day = hl7Date.substring(6, 8);

    // Validate numeric values
    int|error yearInt = int:fromString(year);
    int|error monthInt = int:fromString(month);
    int|error dayInt = int:fromString(day);

    if yearInt is error || monthInt is error || dayInt is error {
        return error("Invalid date components in: " + hl7Date);
    }

    // Basic validation
    if monthInt < 1 || monthInt > 12 {
        return error("Invalid month in date: " + hl7Date);
    }

    if dayInt < 1 || dayInt > 31 {
        return error("Invalid day in date: " + hl7Date);
    }

    // Format as ISO date
    return string `${year}-${month}-${day}`;
}

// Get current timestamp in HL7 format (YYYYMMDDHHmmss)
public isolated function getCurrentHl7Timestamp() returns string {
    time:Utc currentTime = time:utcNow();
    time:Civil civil = time:utcToCivil(currentTime);

    return string `${padZero(civil.year, 4)}${padZero(civil.month, 2)}${padZero(civil.day, 2)}${padZero(civil.hour, 2)}${padZero(civil.minute, 2)}${padZero(<int>civil.second, 2)}`;
}

// Pad number with leading zeros
isolated function padZero(int number, int width) returns string {
    string numStr = number.toString();
    int padLength = width - numStr.length();

    if padLength <= 0 {
        return numStr;
    }

    string padding = "";
    int i = 0;
    while i < padLength {
        padding = padding + "0";
        i = i + 1;
    }

    return padding + numStr;
}

// Validation Functions

// Validate full name using regex pattern
// Equivalent to Mirth's: fullName.match(fullNamePattern)
public isolated function validateFullName(string fullName, string pattern) returns boolean {
    if fullName.trim().length() == 0 {
        return false;
    }

    // Use regex to validate
    regexp:RegExp regexPattern = re `${pattern}`;
    return regexPattern.isFullMatch(fullName);
}

// Validate date of birth using regex pattern
// Equivalent to Mirth's: dateOfBirth.match(dateOfBirthPattern)
public isolated function validateDateOfBirth(string dateOfBirth, string pattern) returns boolean {
    if dateOfBirth.trim().length() == 0 {
        return false;
    }

    // Use regex to validate
    regexp:RegExp regexPattern = re `${pattern}`;
    return regexPattern.isFullMatch(dateOfBirth);
}

// HL7 Message Parsing Functions

// Parse HL7 message and extract field value
// Equivalent to Mirth's: msg['SEGMENT']['FIELD.COMPONENT'].toString()
public isolated function getHl7Field(string message, string segment, string fieldPath) returns string|error {
    // Split message into segments
    regexp:RegExp segmentDelimiter = re `\r`;
    string[] segments = segmentDelimiter.split(message);

    // Find the target segment
    foreach string seg in segments {
        if seg.startsWith(segment) {
            // Split segment into fields
            regexp:RegExp fieldDelimiter = re `\|`;
            string[] fields = fieldDelimiter.split(seg);

            // Parse field path (e.g., "9.1" means field 9, component 1)
            regexp:RegExp dotDelimiter = re `\.`;
            string[] pathParts = dotDelimiter.split(fieldPath);

            if pathParts.length() == 0 {
                return error("Invalid field path: " + fieldPath);
            }

            // Get field index (subtract 1 because HL7 fields are 1-indexed)
            int fieldIndex = check int:fromString(pathParts[0]);

            if fieldIndex >= fields.length() {
                return "";
            }

            string fieldValue = fields[fieldIndex];

            // Handle components (separated by ^)
            if pathParts.length() > 1 {
                regexp:RegExp componentDelimiter = re `\^`;
                string[] components = componentDelimiter.split(fieldValue);
                int componentIndex = check int:fromString(pathParts[1]) - 1;

                if componentIndex < 0 || componentIndex >= components.length() {
                    return "";
                }

                return components[componentIndex].trim();
            }

            return fieldValue.trim();
        }
    }

    return "";
}

// ACK/NACK Generation Functions

// Generate HL7 ACK message
// Equivalent to Mirth's ACK generation
public isolated function generateHl7Ack(
    string messageControlId,
    string acknowledgeCode,
    string? textMessage = ()
) returns string {
    string timestamp = getCurrentHl7Timestamp();
    string ackMessage = string `MSH|^~\\&|BallerinaHL7|BallerinaFacility|SendingApp|SendingFacility|${timestamp}||ACK|${messageControlId}|P|2.5`;

    // Add MSA segment
    string msa = string `MSA|${acknowledgeCode}|${messageControlId}`;

    if textMessage is string && textMessage.length() > 0 {
        msa = msa + "|" + textMessage;
    }

    return string `${ackMessage}\r${msa}`;
}

// Generate ACK response
public isolated function generateAck(string messageControlId, string? textMessage = ()) returns Hl7AckResponse {
    string ackCode = appConfig.hl7Processing.successfulAckCode;
    string ackMessage = generateHl7Ack(messageControlId, ackCode, textMessage);

    return {
        acknowledgeCode: ackCode,
        messageControlId: messageControlId,
        textMessage: textMessage,
        rawAckMessage: ackMessage
    };
}

// Generate NACK response for errors
public isolated function generateNack(
    string messageControlId,
    string errorMessage
) returns Hl7AckResponse {
    string nackCode = appConfig.hl7Processing.errorAckCode;
    string nackMessage = generateHl7Ack(messageControlId, nackCode, errorMessage);

    return {
        acknowledgeCode: nackCode,
        messageControlId: messageControlId,
        textMessage: errorMessage,
        rawAckMessage: nackMessage
    };
}

// Logging Functions

// Log message processing info (equivalent to Mirth's logger.info)
public isolated function logMessageInfo(string messageId, string message) {
    log:printInfo("Processing message", id = messageId, details = message);
}

// Log validation results (equivalent to Mirth's logger.info in validation script)
public isolated function logValidationResult(
    string messageId,
    ValidationResult validation,
    PatientJsonData jsonData
) {
    log:printInfo("Validation completed",
        messageId = messageId,
        isValid = validation.isValid,
        isFullNameValid = validation.isFullNameValid,
        isDateOfBirthValid = validation.isDateOfBirthValid,
        jsonData = jsonData.toString()
    );
}

// Utility Functions

// Generate unique message ID
public isolated function generateMessageId() returns string {
    return uuid:createType1AsString();
}

// Build full name from first and last name
public isolated function buildFullName(string firstName, string lastName) returns string {
    return string `${lastName} ${firstName}`;
}

// Check if value is not null or empty
public isolated function isNotNullOrEmpty(string? value) returns boolean {
    return value is string && value.trim().length() > 0;
}
