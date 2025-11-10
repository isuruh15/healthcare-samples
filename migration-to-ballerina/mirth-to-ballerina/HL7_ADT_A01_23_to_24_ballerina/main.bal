import ballerina/log;
import ballerina/task;
import ballerina/time;
import ballerina/uuid;
import ballerina/io;
import ballerina/lang.runtime;
import xlibb/pipeline;

// Global pipeline handler chain
pipeline:HandlerChain handlerChain = check initializePipeline();

// Service to poll files and process them through the pipeline
service class FilePollerService {
    *task:Job;

    private string inputDirectory;
    private string filePattern;
    private int fileAgeMs;

    isolated function init(string inputDirectory, string filePattern, int fileAgeMs) {
        self.inputDirectory = inputDirectory;
        self.filePattern = filePattern;
        self.fileAgeMs = fileAgeMs;
    }

    public isolated function execute() {
        log:printDebug("Polling for files", directory = self.inputDirectory);

        // List files in input directory
        string[]|error files = listFiles(self.inputDirectory, self.filePattern);

        if files is error {
            log:printError("Error listing files", err = files.message());
            return;
        }

        if files.length() == 0 {
            log:printDebug("No files found to process");
            return;
        }

        log:printInfo("Found files to process", count = files.length());

        // Process each file
        foreach string filePath in files {
            error? result = self.processFile(filePath);
            if result is error {
                log:printError("Error processing file", filePath = filePath, err = result.message());
            }
        }
    }

    isolated function processFile(string filePath) returns error? {
        // Check file age before processing
        boolean isReady = check isFileOlderThan(filePath, self.fileAgeMs);
        if !isReady {
            log:printDebug("File not ready to process (too new)", filePath = filePath);
            return;
        }

        log:printInfo("Processing file", filePath = filePath);

        // Read file content
        string content = check readFileContent(filePath);

        // Extract file name
        string fileName = extractFileName(filePath);

        log:printInfo("Processing message through pipeline", fileName = fileName);

        // Create a message with metadata for the pipeline
        // We'll package the content with metadata as a map
        map<anydata> messageData = {
            "content": content,
            "fileName": fileName,
            "filePath": filePath
        };

        // Execute the message through the pipeline
        // The pipeline will handle:
        // 1. Filtering (validation)
        // 2. Transformation (v2.3 to v2.4)
        // 3. Destination (file writing)
        // 4. Automatic retry on failures
        // 5. Failure store for replay
        pipeline:ExecutionSuccess|pipeline:ExecutionError result = handlerChain.execute(messageData);

        if result is pipeline:ExecutionError {
            log:printError("Pipeline execution failed",
                fileName = fileName,
                err = result.cause().message()
            );
            // Pipeline will handle retry and failure store automatically
            return result.cause();
        }

        log:printInfo("File processed successfully through pipeline",
            fileName = fileName,
            messageId = result.id
        );
    }
}

// ========================================================================================
// PIPELINE INITIALIZATION
// ========================================================================================
// Initialize the xlibb/pipeline HandlerChain with all processors, destinations, and stores
// This creates a resilient message processing pipeline that:
// 1. Validates messages (Filter)
// 2. Transforms HL7 v2.3 to v2.4 (Transformer)
// 3. Writes to output files (Destination)
// 4. Automatically retries failures
// 5. Stores failed messages for replay
// 6. Moves permanently failed messages to dead letter queue
isolated function initializePipeline() returns pipeline:HandlerChain|error {
    log:printInfo("╔════════════════════════════════════════════════════════════════╗");
    log:printInfo("║  Initializing HL7 v2.3 to v2.4 Transformation Pipeline        ║");
    log:printInfo("╚════════════════════════════════════════════════════════════════╝");

    // ========================================
    // Step 1: Create Failure Stores
    // ========================================
    // Failure Store: Temporarily stores failed messages for automatic retry
    InMemoryFailureStore failureStore = new();
    log:printInfo("✓ Failure store created (in-memory)");

    // Dead Letter Store: Permanently stores messages that failed after max retries
    InMemoryDeadLetterStore deadLetterStore = new();
    log:printInfo("✓ Dead letter store created (in-memory)");

    // ========================================
    // Step 2: Initialize Handler Chain
    // ========================================
    // The HandlerChain orchestrates the entire message flow through the pipeline
    log:printInfo("Configuring pipeline handler chain...");

    pipeline:HandlerChain chain = check new(
        // Pipeline name for identification and logging
        name = "hl7V23ToV24Pipeline",

        // PROCESSORS: Execute sequentially in the order specified
        // Each processor can modify the message or filter it out
        // 1. filterHL7Messages - Validates HL7 message format
        // 2. transformHL7Message - Converts v2.3 to v2.4
        processors = [filterHL7Messages, transformHL7Message],

        // DESTINATIONS: Execute in parallel (delivery endpoints)
        // Each destination receives a copy of the processed message
        // Multiple destinations can be specified as an array
        // Here we have one destination: writeToFile
        destinations = writeToFile,

        // FAILURE STORE: Stores messages that fail during processing
        // Failed messages are automatically queued here for replay
        failureStore = failureStore,

        // REPLAY LISTENER CONFIG: Automatic retry mechanism
        // The replay listener polls the failure store and retries failed messages
        replayListenerConfig = {
            // How often to check for failed messages (in seconds)
            pollingInterval: appConfig.pipeline.replayPollingInterval,

            // Maximum number of retry attempts before moving to dead letter queue
            maxRetries: appConfig.pipeline.maxRetries,

            // Where to move messages that exceed max retries
            deadLetterStore: deadLetterStore
        }
    );

    // ========================================
    // Step 3: Log Pipeline Configuration
    // ========================================
    log:printInfo("╔════════════════════════════════════════════════════════════════╗");
    log:printInfo("║  Pipeline Initialized Successfully                             ║");
    log:printInfo("╚════════════════════════════════════════════════════════════════╝");
    log:printInfo("Pipeline Name: " + chain.getName());
    log:printInfo("Processors:");
    log:printInfo("  1. filterHL7Messages (Filter)");
    log:printInfo("  2. transformHL7Message (Transformer)");
    log:printInfo("Destinations:");
    log:printInfo("  1. writeToFile (File Writer with 3 retries)");
    log:printInfo("Failure Handling:");
    log:printInfo("  • Failure Store: In-Memory");
    log:printInfo("  • Dead Letter Store: In-Memory");
    log:printInfo("  • Replay Interval: " + appConfig.pipeline.replayPollingInterval.toString() + " seconds");
    log:printInfo("  • Max Retries: " + appConfig.pipeline.maxRetries.toString());
    log:printInfo("  • Destination Retry Interval: " + appConfig.pipeline.destinationRetryInterval.toString() + " seconds");
    log:printInfo("════════════════════════════════════════════════════════════════");

    return chain;
}

// ========================================================================================
// MAIN FUNCTION - Service Entry Point
// ========================================================================================
// Starts the HL7 transformation service with:
// 1. Pipeline initialization (already done as module-level initialization)
// 2. File polling configuration
// 3. Background task scheduling
// 4. Automatic message processing through the pipeline
public function main() returns error? {
    log:printInfo("╔════════════════════════════════════════════════════════════════╗");
    log:printInfo("║  HL7 ADT A01 v2.3 to v2.4 Transformation Service              ║");
    log:printInfo("╚════════════════════════════════════════════════════════════════╝");

    // ========================================
    // Step 1: Validate and Prepare Directories
    // ========================================
    log:printInfo("Validating directories...");
    check ensureDirectoryExists(appConfig.destination.outputDirectory);
    log:printInfo("✓ Output directory ready: " + appConfig.destination.outputDirectory);

    // ========================================
    // Step 2: Create File Polling Service
    // ========================================
    // The file poller monitors the input directory and feeds messages into the pipeline
    log:printInfo("Creating file polling service...");
    FilePollerService filePoller = new (
        appConfig.'source.inputDirectory,
        appConfig.'source.filePattern,
        appConfig.'source.fileAgeMs
    );
    log:printInfo("✓ File poller configured");

    // ========================================
    // Step 3: Schedule the File Poller
    // ========================================
    // Schedule the poller to run at the configured interval
    log:printInfo("Scheduling file poller task...");
    task:JobId jobId = check task:scheduleJobRecurByFrequency(
        filePoller,
        appConfig.'source.pollingInterval
    );
    log:printInfo("✓ File poller scheduled (Job ID: " + jobId.toString() + ")");

    // ========================================
    // Step 4: Display Service Configuration
    // ========================================
    log:printInfo("╔════════════════════════════════════════════════════════════════╗");
    log:printInfo("║  Service Configuration                                         ║");
    log:printInfo("╚════════════════════════════════════════════════════════════════╝");
    log:printInfo("Source Configuration:");
    log:printInfo("  • Input Directory: " + appConfig.'source.inputDirectory);
    log:printInfo("  • File Pattern: " + appConfig.'source.filePattern);
    log:printInfo("  • Polling Interval: " + appConfig.'source.pollingInterval.toString() + " seconds");
    log:printInfo("  • File Age Threshold: " + appConfig.'source.fileAgeMs.toString() + " ms");
    log:printInfo("");
    log:printInfo("Destination Configuration:");
    log:printInfo("  • Output Directory: " + appConfig.destination.outputDirectory);
    log:printInfo("  • File Name Pattern: " + appConfig.destination.fileNamePattern);
    log:printInfo("");
    log:printInfo("Pipeline Flow:");
    log:printInfo("  Source (File) → Filter (Validate) → Transformer (v2.3→v2.4) → Destination (File)");
    log:printInfo("════════════════════════════════════════════════════════════════");

    // ========================================
    // Step 5: Service Running Status
    // ========================================
    log:printInfo("");
    log:printInfo("✓ HL7 Transformation Service is now RUNNING");
    log:printInfo("✓ Pipeline is ready to process messages");
    log:printInfo("✓ Automatic retry and failure handling enabled");
    log:printInfo("");
    log:printInfo("Press Ctrl+C to stop the service.");
    log:printInfo("════════════════════════════════════════════════════════════════");

    // ========================================
    // Step 6: Keep Service Alive
    // ========================================
    // Keep the main thread alive indefinitely
    // The task scheduler and replay listener will continue running in the background
    // This ensures all background workers (file poller, replay listener) keep running
    worker waitForever {
        // This worker keeps the program running indefinitely
        while true {
            // Sleep for 24 hours at a time
            // The service will continue processing files in the background
            runtime:sleep(86400);
        }
    }
}
