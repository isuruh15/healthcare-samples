import ballerina/time;

// Represents a message in the pipeline
public type Message record {|
    string id;
    string content;
    string fileName;
    string filePath;
    time:Utc timestamp;
    map<anydata> properties;
|};

// Processing status
public enum ProcessingStatus {
    PENDING,
    PROCESSING,
    COMPLETED,
    FAILED
}

// Processing result
public type ProcessingResult record {|
    ProcessingStatus status;
    string? errorMessage;
    anydata? data;
|};
