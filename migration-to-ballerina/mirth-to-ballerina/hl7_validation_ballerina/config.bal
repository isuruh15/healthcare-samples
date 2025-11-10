# TCP server configuration
configurable string tcpHost = "0.0.0.0";
configurable int tcpPort = 6662;
configurable int maxConnections = 10;

# Database configuration
configurable string dbHost = "localhost";
configurable int dbPort = 3306;
configurable string dbName = "mydatabase";
configurable string dbUsername = "root";
configurable string dbPassword = "root";

# MLLP configuration
configurable string mllpStartByte = "\u{000B}";
configurable string mllpEndBytes = "\u{001C}\u{000D}";
configurable string mllpAckByte = "\u{0006}";
configurable string mllpNackByte = "\u{0015}";
configurable int mllpMaxRetries = 2;

# Processing configuration
configurable boolean enableDatabaseInsert = false;
configurable int processingThreads = 1;
configurable decimal readTimeout = 0.0;
configurable decimal writeTimeout = 300.0;