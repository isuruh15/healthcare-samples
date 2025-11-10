
import ballerina/constraint;

# HL7 message structure for patient data
public type Hl7Message record {
    string messageCode;
    string messageTriggerEvent;
    string firstName;
    string lastName;
    string dateOfBirth;
};

# Transformed patient data for processing
public type PatientData record {
    @constraint:String {pattern: re `^[a-zA-Z]{2,}\s[a-zA-Z]{1,}'?-?[a-zA-Z]{2,}\s?([a-zA-Z]{1,})?$`}
    string firstName;
    @constraint:String {pattern: re `^[a-zA-Z]{2,}\s[a-zA-Z]{1,}'?-?[a-zA-Z]{2,}\s?([a-zA-Z]{1,})?$`}
    string lastName;
    @constraint:String {pattern: re `^[12]\d{3}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$`}
    string dateOfBirth;
};

# HL7 response codes
public enum Hl7ResponseCode {
    AA = "AA", // Application Accept
    AE = "AE", // Application Error
    AR = "AR"  // Application Reject
}

# HL7 ACK response structure
public type Hl7Response record {
    Hl7ResponseCode responseCode;
    string responseMessage;
    string messageControlId;
};

# Database patient record
public type PatientRecord record {
    string firstname;
    string lastname;
    string dateofbirth;
};