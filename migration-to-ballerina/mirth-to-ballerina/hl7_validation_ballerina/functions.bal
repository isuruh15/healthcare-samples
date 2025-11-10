import ballerina/log;
import ballerina/time;
import ballerina/sql;
import ballerina/lang.regexp;
import xlibb/pipeline;

# Extract HL7 data from raw message
@pipeline:ProcessorConfig {id: "extractHl7Data"}
isolated function extractHl7Data(pipeline:MessageContext context) returns json|error {
    string hl7Message = check context.getContentWithType();
    
    // Parse HL7 segments (simplified HL7 parsing)
    string:RegExp segmentPattern = re `\r`;
    string[] segments = segmentPattern.split(hl7Message);
    
    string messageCode = "";
    string messageTriggerEvent = "";
    string firstName = "";
    string lastName = "";
    string dateOfBirth = "";
    
    foreach string segment in segments {
        string:RegExp fieldPattern = re `\|`;
        string[] fields = fieldPattern.split(segment);
        
        // MSH segment - message header
        if fields.length() > 0 && fields[0] == "MSH" {
            if fields.length() > 8 {
                string:RegExp componentPattern = re `\^`;
                string[] msgType = componentPattern.split(fields[8]);
                if msgType.length() >= 2 {
                    messageCode = msgType[0].trim();
                    messageTriggerEvent = msgType[1].trim();
                }
            }
        }
        
        // PID segment - patient identification
        if fields.length() > 0 && fields[0] == "PID" {
            if fields.length() > 5 {
                string:RegExp namePattern = re `\^`;
                string[] patientName = namePattern.split(fields[5]);
                if patientName.length() >= 2 {
                    lastName = patientName[0].trim();
                    firstName = patientName[1].trim();
                }
            }
            if fields.length() > 7 {
                dateOfBirth = fields[7].trim();
            }
        }
    }
    
    Hl7Message extractedData = {
        messageCode: messageCode,
        messageTriggerEvent: messageTriggerEvent,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth
    };
    
    context.setProperty("messageCode", messageCode);
    context.setProperty("messageTriggerEvent", messageTriggerEvent);
    
    log:printInfo("Extracted HL7 data", extractedData = extractedData);
    
    return extractedData.toJson();
}

# Transform HL7 data to patient data format
@pipeline:TransformerConfig {id: "transformToPatientData"}
isolated function transformToPatientData(pipeline:MessageContext context) returns json|error {
    json hl7Data = check context.getContentWithType();
    Hl7Message hl7Message = check hl7Data.cloneWithType(Hl7Message);
    
    // Format date from YYYYMMDD to YYYY-MM-DD
    string formattedDate = formatDateOfBirth(hl7Message.dateOfBirth);
    
    PatientData patientData = {
        firstName: hl7Message.firstName,
        lastName: hl7Message.lastName,
        dateOfBirth: formattedDate
    };
    
    context.setProperty("hl7JsonObject", patientData);
    
    log:printInfo("Transformed patient data", patientData = patientData);
    
    return patientData.toJson();
}

# Validate patient fields using regex patterns
@pipeline:ProcessorConfig {id: "validatePatientFields"}
isolated function validatePatientFields(pipeline:MessageContext context) returns error? {
    json patientJson = check context.getContentWithType();
    PatientData patientData = check patientJson.cloneWithType(PatientData);
    
    string fullName = patientData.lastName + " " + patientData.firstName;
    string dateOfBirth = patientData.dateOfBirth;
    
    // Validation patterns from Mirth channel
    string:RegExp fullNamePattern = re `^([a-zA-Z]{2,}\s[a-zA-Z]{1,}'?-?[a-zA-Z]{2,}\s?([a-zA-Z]{1,})?)`;
    string:RegExp datePattern = re `^[12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$`;
    
    boolean isFullNameValid = regexp:isFullMatch(fullNamePattern, fullName);
    boolean isDateValid = regexp:isFullMatch(datePattern, dateOfBirth);
    
    log:printInfo("Field validation results", 
        fullNameValid = isFullNameValid, 
        dateValid = isDateValid,
        jsonObject = patientData.toString()
    );
    
    if !isFullNameValid {
        return error("Invalid full name format: " + fullName);
    }
    
    if !isDateValid {
        return error("Invalid date of birth format: " + dateOfBirth);
    }
    
    context.setProperty("validationPassed", true);
}

# Insert patient data to MySQL database
@pipeline:DestinationConfig {
    id: "insertToDatabase",
    retryConfig: {
        maxRetries: 3,
        retryInterval: 2
    }
}
isolated function insertToDatabase(pipeline:MessageContext context) returns sql:ExecutionResult|error {
    if !enableDatabaseInsert {
        log:printInfo("Database insertion disabled - skipping");
        return {
            affectedRowCount: 0,
            lastInsertId: ()
        };
    }
    
    json patientJson = check context.getContentWithType();
    PatientData patientData = check patientJson.cloneWithType(PatientData);
    
    sql:ParameterizedQuery insertQuery = `INSERT INTO patients (firstname, lastname, dateofbirth) 
                                         VALUES (${patientData.firstName}, ${patientData.lastName}, ${patientData.dateOfBirth})`;
    
    sql:ExecutionResult result = check dbClient->execute(insertQuery);
    
    log:printInfo("Patient data inserted to database", 
        affectedRows = result.affectedRowCount,
        lastInsertId = result.lastInsertId
    );
    
    return result;
}

# Format date from YYYYMMDD to YYYY-MM-DD
isolated function formatDateOfBirth(string dateStr) returns string {
    if dateStr.length() == 8 {
        string year = dateStr.substring(0, 4);
        string month = dateStr.substring(4, 6);
        string day = dateStr.substring(6, 8);
        return year + "-" + month + "-" + day;
    }
    return dateStr;
}

# Generate HL7 ACK response
isolated function generateHl7Response(string originalMessage, Hl7ResponseCode responseCode, string? errorMessage = ()) returns string {
    string currentTime = time:utcToCivil(time:utcNow()).toString();
    string messageControlId = "MSG" + time:utcNow().toString();
    
    string responseMessage = errorMessage ?: (responseCode == AA ? "" : "Message processing failed");
    
    string ackMessage = string `MSH|^~\\&|SYSTEM-B|systemB|SYSTEM-A|systemA|${currentTime}||ACK^A04|${messageControlId}|D|2.5|
MSA|${responseCode}|${messageControlId}|${responseMessage}|`;
    
    return ackMessage;
}

# Extract MLLP framed message
isolated function extractMllpMessage(byte[] data) returns string|error {
    string message = check string:fromBytes(data);
    
    // Remove MLLP framing bytes
    if message.startsWith(mllpStartByte) && message.endsWith(mllpEndBytes) {
        string cleanMessage = message.substring(1);
        int endIndex = cleanMessage.length() - mllpEndBytes.length();
        return cleanMessage.substring(0, endIndex);
    }
    
    return message;
}

# Create MLLP framed response
isolated function createMllpResponse(string ackMessage) returns byte[] {
    string framedMessage = mllpStartByte + ackMessage + mllpEndBytes;
    return framedMessage.toBytes();
}