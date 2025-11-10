import ballerinax/mysql;
import xlibb/pipeline;

import ballerinax/rabbitmq;

# RabbitMQ queue to store the failed orders.
final rabbitmq:MessageStore failureStore = check new("order-failure-store");

# RabbitMQ queue to store the dead-lettered orders.
final rabbitmq:MessageStore deadLetterStore = check new("order-dead-letter-store");

# RabbitMQ queue to trigger the replay of failed orders.
final rabbitmq:MessageStore replayStore = check new("order-replay-store");

# MySQL database client
final mysql:Client dbClient = check new (
    host = dbHost,
    port = dbPort,
    user = dbUsername,
    password = dbPassword,
    database = dbName
);

# Main HL7 processing pipeline
final pipeline:HandlerChain hl7ProcessingPipeline = check new (
    name = "hl7ConversionPipeline",
    processors = [
        extractHl7Data,
        transformToPatientData,
        validatePatientFields
    ],
    destinations = [
        insertToDatabase
    ],
    failureStore = failureStore
);