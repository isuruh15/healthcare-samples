import ballerina/file;

// ========================================================================================
// CONFIGURATION - HL7 Transformation Service
// ========================================================================================
// This configuration maps to the original Mirth Connect channel settings from
// assets/HL7_ADT_A01_23_to_24.xml
//
// Mirth Channel Mapping:
// - Source Connector: File Reader (polling mode)
// - Transformer: HL7 v2.3 to v2.4 conversion
// - Destination: File Writer with MOVE action
// - Pipeline: Filter → Transformer → Destination with automatic retry
// ========================================================================================

// Configuration for the file polling source (maps to Mirth's Source Connector)
public type SourceConfig record {|
    // Directory to poll for HL7 files
    // Mirth equivalent: <host> in FileReceiverProperties
    string inputDirectory;

    // File pattern to match (e.g., "*.txt")
    // Mirth equivalent: <fileFilter>
    string filePattern;

    // Polling interval in seconds (how often to check for new files)
    // Mirth equivalent: <pollingFrequency> (converted from ms to seconds)
    decimal pollingInterval;

    // Minimum file age in milliseconds before processing
    // This prevents processing files that are still being written
    // Mirth equivalent: <fileAge>
    int fileAgeMs;
|};

// Configuration for the file destination (maps to Mirth's Destination Connector)
public type DestinationConfig record {|
    // Directory to write processed/transformed files
    // Mirth equivalent: <moveToDirectory> in afterProcessingAction
    string outputDirectory;

    // File name pattern for processed files
    // Supports placeholders: ${originalFilename}, ${timestamp}, ${DATE}, ${SYSTIME}
    // Mirth equivalent: <moveToFileName>
    string fileNamePattern;
|};

// Pipeline configuration for xlibb/pipeline module behavior
public type PipelineConfig record {|
    // Polling interval for the replay listener (in seconds)
    // How often to check for and retry failed messages
    decimal replayPollingInterval;

    // Maximum number of retry attempts before moving to dead letter queue
    int maxRetries;

    // Retry interval for destination (in seconds)
    // How long to wait between retries at the destination level
    int destinationRetryInterval;
|};

// Main application configuration
public type AppConfig record {|
    SourceConfig 'source;
    DestinationConfig destination;
    PipelineConfig pipeline;
|};

// ========================================================================================
// DEFAULT CONFIGURATION
// ========================================================================================
// This configuration matches the original Mirth Connect channel settings
// Override these values by providing a Config.toml file or environment variables
//
// Example Config.toml:
// [appConfig.source]
// inputDirectory = "/path/to/input"
// filePattern = "*.hl7"
// pollingInterval = 5.0
// fileAgeMs = 1000
//
// [appConfig.destination]
// outputDirectory = "/path/to/output"
// fileNamePattern = "${originalFilename}-processed-${timestamp}"
//
// [appConfig.pipeline]
// replayPollingInterval = 10.0
// maxRetries = 3
// destinationRetryInterval = 2
// ========================================================================================
public configurable AppConfig appConfig = {
    // SOURCE: File polling configuration
    'source: {
        // Mirth: /Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24
        inputDirectory: "/Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24",

        // Mirth: *.txt
        filePattern: "*.txt",

        // Mirth: 5000ms = 5 seconds
        pollingInterval: 5.0,

        // Mirth: 1000ms = 1 second
        fileAgeMs: 1000
    },

    // DESTINATION: File writing configuration
    destination: {
        // Mirth: /Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24/gen
        outputDirectory: "/Users/isurus/wso2/healthcare/other/rnd/mirth/hl7_v23tov24/gen",

        // Mirth: ${originalFilename}-ProcessedOn-${DATE}${SYSTIME}
        // We use ${timestamp} which combines DATE and SYSTIME
        fileNamePattern: "${originalFilename}-ProcessedOn-${timestamp}"
    },

    // PIPELINE: xlibb/pipeline behavior configuration
    pipeline: {
        // Check for failed messages every 10 seconds
        replayPollingInterval: 10.0,

        // Retry up to 3 times before moving to dead letter queue
        maxRetries: 3,

        // Wait 2 seconds between destination retries
        destinationRetryInterval: 2
    }
};
