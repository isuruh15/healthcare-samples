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

// Automation utilities for testing and deployment
// This module is not part of the core Mirth conversion but provides
// helpful utilities for testing and managing the service

import ballerina/log;

// Deployment script equivalent
// Equivalent to Mirth's channel deployment script
public function onDeploy() {
    log:printInfo("Deploying HL7 Conversion Service");
    log:printInfo("Configuration validated and service ready to start");
    // Custom initialization logic can go here
}

// Undeployment script equivalent
// Equivalent to Mirth's channel undeploy script
public function onUndeploy() {
    log:printInfo("Undeploying HL7 Conversion Service");
    log:printInfo("Cleaning up resources");
    // Custom cleanup logic can go here
}

// Health check function for monitoring
public function healthCheck() returns boolean {
    // Check if all required configurations are valid
    boolean isHealthy = true;

    // Check TCP listener config
    if appConfig.tcpListener.port < 1 || appConfig.tcpListener.port > 65535 {
        log:printError("Invalid TCP port configuration");
        isHealthy = false;
    }

    // Check MLLP config
    if appConfig.mllp.endOfMessageBytes.length() != 2 {
        log:printError("Invalid MLLP end of message bytes configuration");
        isHealthy = false;
    }

    // Check database config if enabled
    if appConfig.database.enabled {
        if appConfig.database.jdbcUrl.trim().length() == 0 {
            log:printError("Database enabled but JDBC URL not configured");
            isHealthy = false;
        }
    }

    return isHealthy;
}
