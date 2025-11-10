import ballerina/log;
import ballerina/messaging;

// In-memory failure store for capturing failed messages
// Implements ballerina/messaging:Store interface
// In production, this could be replaced with a persistent store (database, file-based, etc.)
public isolated class InMemoryFailureStore {
    *messaging:Store;

    private map<messaging:Message> failedMessages = {};
    private string? topMessageId = ();

    public isolated remote function store(anydata payload) returns error? {
        lock {
            messaging:Message message = {
                payload: payload
            };
            self.failedMessages[message.id] = message.clone();
            if self.topMessageId is () {
                self.topMessageId = message.id;
            }
            log:printWarn("Message added to failure store", messageId = message.id);
        }
    }

    public isolated remote function retrieve() returns messaging:Message?|error {
        lock {
            string? topId = self.topMessageId;
            if topId is string && self.failedMessages.hasKey(topId) {
                return self.failedMessages.get(topId).clone();
            }
            return ();
        }
    }

    public isolated remote function acknowledge(string id, boolean success = true) returns error? {
        lock {
            if self.failedMessages.hasKey(id) {
                _ = self.failedMessages.remove(id);
                log:printInfo("Message acknowledged and removed from failure store", messageId = id, success = success);

                // Update top message
                if id == self.topMessageId {
                    string[] keys = self.failedMessages.keys();
                    self.topMessageId = keys.length() > 0 ? keys[0] : ();
                }
            }
        }
    }

    // Additional helper method
    public isolated function getCount() returns int {
        lock {
            return self.failedMessages.length();
        }
    }
}

// In-memory dead letter store for messages that failed after maximum retries
public isolated class InMemoryDeadLetterStore {
    *messaging:Store;

    private map<messaging:Message> deadLetterMessages = {};
    private string? topMessageId = ();

    public isolated remote function store(anydata payload) returns error? {
        lock {
            messaging:Message message = {
                payload: payload
            };
            self.deadLetterMessages[message.id] = message.clone();
            if self.topMessageId is () {
                self.topMessageId = message.id;
            }
            log:printError("Message moved to dead letter store", messageId = message.id);
        }
    }

    public isolated remote function retrieve() returns messaging:Message?|error {
        lock {
            string? topId = self.topMessageId;
            if topId is string && self.deadLetterMessages.hasKey(topId) {
                return self.deadLetterMessages.get(topId).clone();
            }
            return ();
        }
    }

    public isolated remote function acknowledge(string id, boolean success = true) returns error? {
        lock {
            if self.deadLetterMessages.hasKey(id) {
                _ = self.deadLetterMessages.remove(id);
                log:printInfo("Message acknowledged and removed from dead letter store", messageId = id, success = success);

                // Update top message
                if id == self.topMessageId {
                    string[] keys = self.deadLetterMessages.keys();
                    self.topMessageId = keys.length() > 0 ? keys[0] : ();
                }
            }
        }
    }

    // Additional method to inspect dead letter messages
    public isolated function getCount() returns int {
        lock {
            return self.deadLetterMessages.length();
        }
    }
}
