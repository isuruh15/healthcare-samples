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

// Type definitions for the HL7 to FHIR conversion pipeline

import ballerina/constraint;
import ballerina/time;

// HL7 Message Header (MSH segment) extracted fields
public type Hl7MessageHeader record {|
    string messageCode; // MSH.9.1 - Message type (e.g., ADT, ORU)
    string triggerEvent; // MSH.9.2 - Trigger event (e.g., A01, A04)
    string sendingApplication?; // MSH.3
    string sendingFacility?; // MSH.4
    string receivingApplication?; // MSH.5
    string receivingFacility?; // MSH.6
    string messageControlId?; // MSH.10
    string messageDateTime?; // MSH.7
|};

// Patient demographic data extracted from HL7 PID segment
public type PatientDemographics record {|
    @constraint:String {
        minLength: 1,
        maxLength: 100
    }
    string firstName; // PID.5.2

    @constraint:String {
        minLength: 1,
        maxLength: 100
    }
    string lastName; // PID.5.1

    string dateOfBirth; // PID.7.1 (original YYYYMMDD format)

    string? patientId; // PID.3 (optional)
    string? gender; // PID.8 (optional)
    string? address; // PID.11 (optional)
    string? phoneNumber; // PID.13 (optional)
|};

// Transformed patient data in JSON format (equivalent to Mirth's hl7_json_object)
public type PatientJsonData record {|
    string first_name;
    string last_name;
    string date_of_birth; // ISO format YYYY-MM-DD
    string? patient_id;
    string? gender;
    string? full_name; // Computed field: lastName + " " + firstName
|};

// Validation result for patient data
public type ValidationResult record {|
    boolean isValid;
    boolean isFullNameValid;
    boolean isDateOfBirthValid;
    string? fullNameError;
    string? dobError;
|};

// HL7 Message wrapper
public type Hl7Message record {|
    string rawMessage; // Original HL7 message
    Hl7MessageHeader header;
    PatientDemographics patient;
    time:Utc receivedTimestamp; // When message was received
    string messageId; // Unique identifier for tracking
|};

// Database insert record (for MySQL destination)
public type PatientDatabaseRecord record {|
    string firstname;
    string lastname;
    string dateofbirth; // Original YYYYMMDD format for DB
    string? patientid;
|};

// ACK/NACK response message
public type Hl7AckResponse record {|
    string acknowledgeCode; // AA, AE, AR, CA, CE, CR
    string messageControlId; // MSH.10 from original message
    string textMessage?; // Error or success message
    string rawAckMessage; // Complete HL7 ACK message
|};

// Error details for failed message processing
public type ProcessingError record {|
    string errorCode;
    string errorMessage;
    string? stackTrace;
    time:Utc errorTimestamp;
|};

// Message context for pipeline processing
// This is similar to Mirth's channel map for storing variables
public type MessageContext record {|
    string messageId;
    Hl7Message hl7Message;
    PatientJsonData? jsonData;
    ValidationResult? validationResult;
    ProcessingError? 'error;
    map<anydata> properties; // Additional properties (like Mirth's channel map)
|};

// MLLP Frame wrapper
public type MllpFrame record {|
    byte startOfMessage; // 0x0B
    string message; // HL7 message content
    byte[] endOfMessage; // [0x1C, 0x0D]
|};
