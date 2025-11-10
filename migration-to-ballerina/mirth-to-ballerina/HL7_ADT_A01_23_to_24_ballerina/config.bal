import ballerina/file;

// Configuration for the file polling source
public type SourceConfig record {|
    // Directory to poll for HL7 files
    string inputDirectory;
    // File pattern to match (e.g., "*.txt")
    string filePattern;
    // Polling interval in milliseconds
    decimal pollingInterval;
    // Minimum file age in milliseconds before processing
    int fileAgeMs;
|};

// Configuration for the file destination
public type DestinationConfig record {|
    // Directory to move processed files
    string outputDirectory;
    // File name pattern for processed files
    string fileNamePattern;
|};

// Application configuration
public type AppConfig record {|
    SourceConfig 'source;
    DestinationConfig destination;
|};

// Default configuration matching the Mirth channel settings
public configurable AppConfig appConfig = {
    'source: {
        inputDirectory: "/Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24",
        filePattern: "*.txt",
        pollingInterval: 5.0,
        fileAgeMs: 1000
    },
    destination: {
        outputDirectory: "/Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24/gen",
        fileNamePattern: "${originalFilename}-ProcessedOn-${timestamp}"
    }
};
