import ballerina/file;
import ballerina/io;
import ballerina/log;
import ballerina/time;

// Read file content
public isolated function readFileContent(string filePath) returns string|error {
    log:printDebug("Reading file", filePath = filePath);
    string content = check io:fileReadString(filePath);
    return content;
}

// Write content to file
public isolated function writeFileContent(string filePath, string content) returns error? {
    log:printDebug("Writing to file", filePath = filePath);
    check io:fileWriteString(filePath, content);
}

// List files in directory matching pattern
public isolated function listFiles(string directory, string pattern) returns string[]|error {
    log:printDebug("Listing files in directory", directory = directory, pattern = pattern);

    // Check if directory exists
    boolean dirExists = check file:test(directory, file:EXISTS);
    if !dirExists {
        return error(string `Directory does not exist: ${directory}`);
    }

    // Read directory
    file:MetaData[] files = check file:readDir(directory);

    string[] matchingFiles = [];
    foreach file:MetaData fileMetadata in files {
        if !fileMetadata.dir {
            string fileName = extractFileName(fileMetadata.absPath);
            if matchesPattern(fileName, pattern) {
                matchingFiles.push(fileMetadata.absPath);
            }
        }
    }

    log:printDebug("Found matching files", count = matchingFiles.length());
    return matchingFiles;
}

// Move file to destination directory
public isolated function moveFile(string sourcePath, string destinationPath) returns error? {
    log:printDebug("Moving file", 'source = sourcePath, destination = destinationPath);

    // Ensure destination directory exists
    string destDir = extractDirectoryPath(destinationPath);
    check ensureDirectoryExists(destDir);

    // Copy file to destination
    check file:copy(sourcePath, destinationPath, file:REPLACE_EXISTING);

    // Delete source file
    check file:remove(sourcePath);

    log:printInfo("File moved successfully", 'source = sourcePath, destination = destinationPath);
}

// Ensure directory exists, create if it doesn't
public isolated function ensureDirectoryExists(string directory) returns error? {
    boolean exists = check file:test(directory, file:EXISTS);
    if !exists {
        log:printInfo("Creating directory", directory = directory);
        check file:createDir(directory, file:RECURSIVE);
    }
}

// Get file metadata
public isolated function getFileMetadata(string filePath) returns file:MetaData|error {
    return file:getMetaData(filePath);
}

// Check if file is older than specified milliseconds
public isolated function isFileOlderThan(string filePath, int ageMs) returns boolean|error {
    file:MetaData metadata = check file:getMetaData(filePath);
    time:Utc modifiedTime = metadata.modifiedTime;
    time:Utc currentTime = time:utcNow();

    time:Seconds? ageInSeconds = time:utcDiffSeconds(currentTime, modifiedTime);

    if ageInSeconds is () {
        // If we can't calculate the difference, assume the file is ready
        return true;
    }

    decimal ageInMsDecimal = ageInSeconds * 1000;

    return ageInMsDecimal >= <decimal>ageMs;
}

// Extract file name from path
isolated function extractFileName(string filePath) returns string {
    string[] parts = re `/`.split(filePath);
    return parts[parts.length() - 1];
}

// Extract directory path from file path
isolated function extractDirectoryPath(string filePath) returns string {
    int? lastSlashIndex = filePath.lastIndexOf("/");
    if lastSlashIndex is int {
        return filePath.substring(0, lastSlashIndex);
    }
    return ".";
}

// Simple pattern matching (supports * wildcard)
isolated function matchesPattern(string fileName, string pattern) returns boolean {
    // Convert glob pattern to regex-like matching
    if pattern == "*" || pattern == "*.*" {
        return true;
    }

    if pattern.startsWith("*.") {
        string extension = pattern.substring(1);
        return fileName.endsWith(extension);
    }

    return fileName == pattern;
}
