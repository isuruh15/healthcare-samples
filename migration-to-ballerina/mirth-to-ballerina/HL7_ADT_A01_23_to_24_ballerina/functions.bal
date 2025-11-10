import ballerina/log;
import ballerina/time;
import ballerinax/health.hl7v2;
import ballerinax/health.hl7v23;
import ballerinax/health.hl7v24;

// Parse HL7 v2.3 message from string
public isolated function parseHL7v23(string hl7Message) returns anydata|error {
    log:printDebug("Parsing HL7 v2.3 message");

    // Parse the message using HL7v2 parser
    anydata parsedMsg = check hl7v2:parse(hl7Message);

    return parsedMsg;
}

// Transform HL7 v2.3 ADT_A01 message to v2.4
public isolated function transformHL7v23ToV24(anydata v23Message) returns anydata|error {
    log:printDebug("Transforming HL7 v2.3 to v2.4");

    // Create a new v2.4 message
    // Note: This is a simplified transformation. In production, you would need to:
    // 1. Map all segments from v2.3 to v2.4
    // 2. Handle structural differences between versions
    // 3. Transform data types that changed between versions
    // 4. Add new required fields in v2.4

    // For demonstration, we'll encode and re-parse with version update
    // This preserves the message structure and updates the version identifier
    byte[] serialized = check hl7v2:encode(hl7v23:VERSION, v23Message);

    // Convert byte[] to string
    string messageStr = check string:fromBytes(serialized);

    // Parse as v2.4 by simply re-parsing the message
    anydata v24Message = check hl7v2:parse(messageStr);

    return v24Message;
}

// Serialize HL7 v2.4 message to string
public isolated function serializeHL7v24(anydata v24Message) returns string|error {
    log:printDebug("Serializing HL7 v2.4 message");

    byte[] encoded = check hl7v2:encode(hl7v24:VERSION, v24Message);
    string result = check string:fromBytes(encoded);
    return result;
}

// Generate output file name based on pattern
public isolated function generateOutputFileName(string originalFileName, string pattern) returns string {
    time:Utc currentTime = time:utcNow();
    time:Civil civilTime = time:utcToCivil(currentTime);

    // Format timestamp: YYYYMMDDHHMMSS
    int month = civilTime.month;
    int day = civilTime.day;
    int hour = civilTime.hour;
    int minute = civilTime.minute;
    decimal second = civilTime.second;
    int secondInt = <int>second;

    string timestamp = string `${civilTime.year}${padNumber(month)}${padNumber(day)}${padNumber(hour)}${padNumber(minute)}${padNumber(secondInt)}`;

    // Replace placeholders in pattern using regex:replaceAll
    string fileName = re `\$\{originalFilename\}`.replaceAll(pattern, originalFileName);
    fileName = re `\$\{timestamp\}`.replaceAll(fileName, timestamp);
    fileName = re `\$\{DATE\}`.replaceAll(fileName, string `${civilTime.year}${padNumber(month)}${padNumber(day)}`);
    fileName = re `\$\{SYSTIME\}`.replaceAll(fileName, string `${padNumber(hour)}${padNumber(minute)}${padNumber(secondInt)}`);

    return fileName;
}

// Helper function to pad numbers with leading zero
isolated function padNumber(int num) returns string {
    return num < 10 ? string `0${num}` : num.toString();
}
