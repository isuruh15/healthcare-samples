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

// Configuration module for the HL7 to FHIR conversion pipeline
// All configurable parameters are defined here for easy customization

// TCP Listener Configuration (equivalent to Mirth TCP Source Connector)
public type TcpListenerConfig record {|
    // Network configuration
    string host = "0.0.0.0"; // Listen on all interfaces
    int port = 6662; // TCP port to listen on

    // Connection management
    int maxConnections = 10; // Maximum concurrent connections
    boolean keepConnectionOpen = true; // Keep connections alive
    int reconnectInterval = 5000; // Reconnect interval in milliseconds
    int receiveTimeout = 0; // Receive timeout (0 = no timeout)
    int bufferSize = 65536; // Buffer size for receiving data
|};

// MLLP Configuration (Minimum Lower Layer Protocol)
public type MllpConfig record {|
    // MLLP framing bytes
    byte startOfMessageByte = 0x0B; // Vertical tab (default)
    byte[] endOfMessageBytes = [0x1C, 0x0D]; // File separator + carriage return
    byte ackByte = 0x06; // ASCII ACK
    byte nackByte = 0x15; // ASCII NAK

    // MLLP behavior
    boolean useMLLPv2 = false; // Use MLLP version 2
    int maxRetries = 2; // Maximum retry attempts
|};

// HL7 Processing Configuration
public type Hl7ProcessingConfig record {|
    // Processing options
    int processingThreads = 1; // Number of processing threads
    int queueBufferSize = 1000; // Queue buffer size for messages
    boolean respondAfterProcessing = true; // Send response after processing

    // ACK configuration
    string successfulAckCode = "AA"; // Application Accept
    string errorAckCode = "AE"; // Application Error
    string rejectedAckCode = "AR"; // Application Reject
|};

// Validation Configuration
public type ValidationConfig record {|
    // Name validation regex pattern
    string fullNamePattern = "^([a-zA-Z]{2,}\\s[a-zA-Z]{1,}\\'?-?[a-zA-Z]{2,}\\s?([a-zA-Z]{1,})?)";

    // Date of birth validation regex pattern (YYYYMMDD format)
    string dateOfBirthPattern = "([12]\\d{3}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01]))";

    // Enable/disable validation
    boolean enableNameValidation = true;
    boolean enableDobValidation = true;
|};

// Database Configuration (MySQL - currently disabled in original channel)
public type DatabaseConfig record {|
    boolean enabled = false; // Enable/disable database writes
    string jdbcUrl = "jdbc:mysql://localhost:3306/mydatabase";
    string username = "root";
    string password = ""; // Should be configured via Config.toml
    string driver = "com.mysql.cj.jdbc.Driver";
    int connectionPoolSize = 10;
|};

// Pipeline Configuration
public type PipelineConfig record {|
    string name = "hl7ConversionPipeline";
    boolean enableFailureStore = true; // Enable message failure store
    boolean enableDeadLetterQueue = true; // Enable dead letter queue
    int retryMaxAttempts = 3; // Maximum retry attempts for destinations
    int retryInterval = 2; // Retry interval in seconds
|};

// Application Configuration
public type AppConfig record {|
    TcpListenerConfig tcpListener;
    MllpConfig mllp;
    Hl7ProcessingConfig hl7Processing;
    ValidationConfig validation;
    DatabaseConfig database;
    PipelineConfig pipeline;
|};

// Configurable variables (can be overridden in Config.toml)
configurable TcpListenerConfig tcpListener = {
    host: "0.0.0.0",
    port: 6662,
    maxConnections: 10,
    keepConnectionOpen: true,
    reconnectInterval: 5000,
    receiveTimeout: 0,
    bufferSize: 65536
};

configurable MllpConfig mllp = {
    startOfMessageByte: 0x0B,
    endOfMessageBytes: [0x1C, 0x0D],
    ackByte: 0x06,
    nackByte: 0x15,
    useMLLPv2: false,
    maxRetries: 2
};

configurable Hl7ProcessingConfig hl7Processing = {
    processingThreads: 1,
    queueBufferSize: 1000,
    respondAfterProcessing: true,
    successfulAckCode: "AA",
    errorAckCode: "AE",
    rejectedAckCode: "AR"
};

configurable ValidationConfig validation = {
    fullNamePattern: "^([a-zA-Z]{2,}\\s[a-zA-Z]{1,}\\'?-?[a-zA-Z]{2,}\\s?([a-zA-Z]{1,})?)",
    dateOfBirthPattern: "([12]\\d{3}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01]))",
    enableNameValidation: true,
    enableDobValidation: true
};

configurable DatabaseConfig database = {
    enabled: false,
    jdbcUrl: "jdbc:mysql://localhost:3306/mydatabase",
    username: "root",
    password: "",
    driver: "com.mysql.cj.jdbc.Driver",
    connectionPoolSize: 10
};

configurable PipelineConfig pipeline = {
    name: "hl7ConversionPipeline",
    enableFailureStore: true,
    enableDeadLetterQueue: true,
    retryMaxAttempts: 3,
    retryInterval: 2
};

// Application configuration instance
public final AppConfig & readonly appConfig = {
    tcpListener,
    mllp,
    hl7Processing,
    validation,
    database,
    pipeline
};
