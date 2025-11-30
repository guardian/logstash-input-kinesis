#!/bin/bash
# Initialize localstack resources

echo "Waiting for localstack to be ready..."
sleep 5

# Create Kinesis stream
echo "Creating Kinesis stream..."
aws --endpoint-url=http://localhost:4566 kinesis create-stream \
    --stream-name test-logstash-stream \
    --shard-count 1 \
    --region us-east-1

# Wait for stream to be active
echo "Waiting for stream to become active..."
aws --endpoint-url=http://localhost:4566 kinesis wait stream-exists \
    --stream-name test-logstash-stream \
    --region us-east-1

echo "Localstack resources initialized successfully!"
