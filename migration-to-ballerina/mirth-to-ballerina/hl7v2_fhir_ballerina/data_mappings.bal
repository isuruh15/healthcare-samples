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

// Data mapping functions for transforming HL7 messages
// Equivalent to Mirth's MapperStep and JavaScript transformers

import ballerina/log;
import ballerina/time;

// Parse HL7 message and extract all relevant fields
// Equivalent to Mirth's Source Transformer MapperSteps
public isolated function parseHl7Message(string rawMessage, string messageId) returns Hl7Message|error {
    // Extract Message Header fields (MSH segment)
    string messageCode = check getHl7Field(rawMessage, "MSH", "9.1");
    string triggerEvent = check getHl7Field(rawMessage, "MSH", "9.2");
    string sendingApp = check getHl7Field(rawMessage, "MSH", "3");
    string sendingFacility = check getHl7Field(rawMessage, "MSH", "4");
    string receivingApp = check getHl7Field(rawMessage, "MSH", "5");
    string receivingFacility = check getHl7Field(rawMessage, "MSH", "6");
    string messageControlId = check getHl7Field(rawMessage, "MSH", "10");
    string messageDateTime = check getHl7Field(rawMessage, "MSH", "7");

    log:printDebug("Extracted message header",
        messageCode = messageCode,
        triggerEvent = triggerEvent,
        messageControlId = messageControlId
    );

    // Extract Patient Demographics (PID segment)
    string firstName = check getHl7Field(rawMessage, "PID", "5.2");
    string lastName = check getHl7Field(rawMessage, "PID", "5.1");
    string dateOfBirth = check getHl7Field(rawMessage, "PID", "7.1");
    string patientId = check getHl7Field(rawMessage, "PID", "3.1");
    string gender = check getHl7Field(rawMessage, "PID", "8");
    string address = check getHl7Field(rawMessage, "PID", "11");
    string phoneNumber = check getHl7Field(rawMessage, "PID", "13");

    log:printDebug("Extracted patient demographics",
        firstName = firstName,
        lastName = lastName,
        dateOfBirth = dateOfBirth,
        patientId = patientId
    );

    // Validate required fields
    if messageCode.trim().length() == 0 {
        return error("Message code (MSH.9.1) is required");
    }

    if firstName.trim().length() == 0 || lastName.trim().length() == 0 {
        return error("Patient first name and last name are required");
    }

    if dateOfBirth.trim().length() == 0 {
        return error("Patient date of birth is required");
    }

    // Construct HL7 message structure
    Hl7Message hl7Message = {
        rawMessage: rawMessage,
        header: {
            messageCode: messageCode.trim(),
            triggerEvent: triggerEvent.trim(),
            sendingApplication: sendingApp.trim(),
            sendingFacility: sendingFacility.trim(),
            receivingApplication: receivingApp.trim(),
            receivingFacility: receivingFacility.trim(),
            messageControlId: messageControlId.trim(),
            messageDateTime: messageDateTime.trim()
        },
        patient: {
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            dateOfBirth: dateOfBirth.trim(),
            patientId: patientId.trim().length() > 0 ? patientId.trim() : (),
            gender: gender.trim().length() > 0 ? gender.trim() : (),
            address: address.trim().length() > 0 ? address.trim() : (),
            phoneNumber: phoneNumber.trim().length() > 0 ? phoneNumber.trim() : ()
        },
        receivedTimestamp: time:utcNow(),
        messageId: messageId
    };

    return hl7Message;
}

// Transform HL7 data to JSON format
// Equivalent to Mirth's JavaScript transformer "Conversion" step
// Original code:
// var hl7JsonObject = {};
// hl7JsonObject.first_name = msg['PID']['PID.5']['PID.5.2'].toString();
// hl7JsonObject.last_name = msg['PID']['PID.5']['PID.5.1'].toString();
// hl7JsonObject.date_of_birth = moment(msg['PID']['PID.7']['PID.7.1'].toString(), 'YYYYMMDD').format('YYYY-MM-DD');
// channelMap.put('hl7_json_object', hl7JsonObject);
public isolated function transformToJson(Hl7Message hl7Message) returns PatientJsonData|error {
    // Convert date from YYYYMMDD to YYYY-MM-DD (ISO format)
    string isoDate = check convertHl7DateToIso(hl7Message.patient.dateOfBirth);

    // Build full name
    string fullName = buildFullName(hl7Message.patient.firstName, hl7Message.patient.lastName);

    PatientJsonData jsonData = {
        first_name: hl7Message.patient.firstName,
        last_name: hl7Message.patient.lastName,
        date_of_birth: isoDate,
        patient_id: hl7Message.patient.patientId,
        gender: hl7Message.patient.gender,
        full_name: fullName
    };

    log:printDebug("Transformed to JSON",
        firstName = jsonData.first_name,
        lastName = jsonData.last_name,
        dateOfBirth = jsonData.date_of_birth
    );

    return jsonData;
}

// Validate patient data
// Equivalent to Mirth's "Fields Validation" destination JavaScript
// Original code:
// const fullName = $('Last Name') + " " + $('First Name');
// const dateOfBirth = $('Date Of Birth');
// const fullNamePattern = /^([a-zA-Z]{2,}\s[a-zA-Z]{1,}\'?-?[a-zA-Z]{2,}\s?([a-zA-Z]{1,})?)/g;
// const dateOfBirthPattern = /([12]\d{3}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01]))/g;
// const isFullNameValid = fullName.match(fullNamePattern);
// const isDateOfBirthValid = dateOfBirth.match(dateOfBirthPattern);
public isolated function validatePatientData(
    PatientJsonData jsonData,
    Hl7Message hl7Message
) returns ValidationResult {
    string fullName = buildFullName(jsonData.first_name, jsonData.last_name);
    string dateOfBirth = hl7Message.patient.dateOfBirth; // Original YYYYMMDD format

    boolean isFullNameValid = true;
    boolean isDateOfBirthValid = true;
    string? fullNameError = ();
    string? dobError = ();

    // Validate full name if enabled
    if appConfig.validation.enableNameValidation {
        isFullNameValid = validateFullName(fullName, appConfig.validation.fullNamePattern);
        if !isFullNameValid {
            fullNameError = string `Full name "${fullName}" does not match required pattern`;
            log:printWarn("Name validation failed", fullName = fullName);
        }
    }

    // Validate date of birth if enabled
    if appConfig.validation.enableDobValidation {
        isDateOfBirthValid = validateDateOfBirth(dateOfBirth, appConfig.validation.dateOfBirthPattern);
        if !isDateOfBirthValid {
            dobError = string `Date of birth "${dateOfBirth}" does not match required pattern (YYYYMMDD)`;
            log:printWarn("DOB validation failed", dateOfBirth = dateOfBirth);
        }
    }

    ValidationResult result = {
        isValid: isFullNameValid && isDateOfBirthValid,
        isFullNameValid: isFullNameValid,
        isDateOfBirthValid: isDateOfBirthValid,
        fullNameError: fullNameError,
        dobError: dobError
    };

    return result;
}

// Convert to database record format
// Equivalent to preparing data for Mirth's MySQL Insert destination
public isolated function toDatabaseRecord(
    Hl7Message hl7Message,
    PatientJsonData jsonData
) returns PatientDatabaseRecord {
    return {
        firstname: jsonData.first_name,
        lastname: jsonData.last_name,
        dateofbirth: hl7Message.patient.dateOfBirth, // Store original YYYYMMDD format
        patientid: jsonData.patient_id
    };
}

// Create message context for pipeline processing
// Similar to Mirth's channel map that stores variables
public isolated function createMessageContext(
    Hl7Message hl7Message,
    PatientJsonData jsonData,
    ValidationResult validation
) returns MessageContext {
    map<anydata> properties = {
        "Message code": hl7Message.header.messageCode,
        "Message Trigger Event": hl7Message.header.triggerEvent,
        "First Name": hl7Message.patient.firstName,
        "Last Name": hl7Message.patient.lastName,
        "Date Of Birth": hl7Message.patient.dateOfBirth,
        "hl7_json_object": jsonData
    };

    return {
        messageId: hl7Message.messageId,
        hl7Message: hl7Message,
        jsonData: jsonData,
        validationResult: validation,
        'error: (),
        properties: properties
    };
}
