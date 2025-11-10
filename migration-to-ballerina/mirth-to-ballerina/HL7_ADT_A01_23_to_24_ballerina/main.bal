import ballerina/log;
import ballerina/task;
import ballerina/time;
import ballerina/uuid;
import ballerina/io;
import ballerina/runtime;

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
        string messageId = uuid:createType1AsString();

        // Log processing start
        logProcessingStatus(messageId);

        // Filter message
        boolean isValid = filterHL7Messages(content);
        if !isValid {
            log:printWarn("Message filtered out", fileName = fileName);
            return;
        }

        // Transform message through pipeline
        string|error transformResult = transformHL7Message(content);

        if transformResult is error {
            log:printError("Transformation failed",
                fileName = fileName,
                err = transformResult.message()
            );

            // On error, keep the file for retry
            return transformResult;
        }

        string transformedContent = transformResult;

        // Write transformed content to output file
        string originalFileName = fileName;
        string outputFileName = generateOutputFileName(originalFileName, appConfig.destination.fileNamePattern);
        string outputPath = string `${appConfig.destination.outputDirectory}/${outputFileName}`;

        // Write the transformed content
        check io:fileWriteString(outputPath, transformedContent);

        // Move original file to processed directory
        string processedFilePath = string `${appConfig.destination.outputDirectory}/${originalFileName}`;
        check moveFile(filePath, processedFilePath);

        log:printInfo("File processed successfully",
            originalFile = filePath,
            transformedFile = outputPath,
            movedTo = processedFilePath
        );
    }
}

// Main function to start the service
public function main() returns error? {
    log:printInfo("Starting HL7 ADT A01 v2.3 to v2.4 Transformation Service");

    // Ensure output directory exists
    check ensureDirectoryExists(appConfig.destination.outputDirectory);

    // Create file poller job
    FilePollerService filePoller = new (
        appConfig.'source.inputDirectory,
        appConfig.'source.filePattern,
        appConfig.'source.fileAgeMs
    );

    // Schedule the file poller
    task:JobId jobId = check task:scheduleJobRecurByFrequency(
        filePoller,
        appConfig.'source.pollingInterval
    );

    log:printInfo("HL7 Transformation Service started successfully",
        inputDirectory = appConfig.'source.inputDirectory,
        outputDirectory = appConfig.destination.outputDirectory,
        pollingInterval = appConfig.'source.pollingInterval
    );

    log:printInfo("Service is running. Press Ctrl+C to stop.");

    // Keep the service running - wait indefinitely
    // The task scheduler will continue running in the background
    runtime:registerListener(());
    runtime:onGracefulStop();
}
