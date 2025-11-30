# Integration Tests

This directory contains integration tests for the logstash-input-kinesis plugin.

## ⚠️ Important: Current Test Scope

This plugin now uses Kinesis Client Library (KCL) v2.7.2, which supports custom endpoint configuration for testing with LocalStack.

## What This Test Validates

The integration test validates:

✅ **Build Process**
- Gem package builds successfully
- All dependencies are included
- VERSION file is properly packaged

✅ **Plugin Installation**  
- Plugin installs in Logstash without errors
- JAR dependencies are resolved
- Plugin appears in Logstash plugin registry

✅ **Plugin Initialization**
- Plugin registers with Logstash
- Configuration is parsed correctly
- KCL v2.7.2 configuration initializes with endpoint overrides
- AWS SDK libraries load

✅ **Infrastructure**
- LocalStack services start correctly
- Messages can be sent to Kinesis stream
- HTTP mock server is ready

✅ **KCL LocalStack Integration**
- KCL v2.7.2 successfully connects to LocalStack endpoints
- DynamoDB lease management works with LocalStack
- Kinesis stream consumer registration works
- Messages are retrieved from LocalStack Kinesis

## Current Status

✅ **Full integration with LocalStack is functional!**

The plugin now uses KCL v2.7.2 with custom endpoint configuration support. Testing confirms:
- KCL connects to LocalStack Kinesis and DynamoDB endpoints
- Stream consumer registration works
- Messages are retrieved from Kinesis
- The ByteBuffer handling for KCL 2.x has been fixed

⚠️ **Test refinement needed**: The integration test script needs adjustment for proper base64 encoding when sending test messages to match real-world Kinesis data format.

## Test Flow

1. Build gem package
2. Start LocalStack (Kinesis + DynamoDB)
3. Start HTTP Mock Server
4. Start Logstash and install plugin
5. Wait for plugin to register
6. Plugin initializes KCL with LocalStack endpoints
7. KCL connects to LocalStack and registers stream consumer
8. Create Kinesis stream in LocalStack
9. Send test message to stream
10. KCL retrieves messages from LocalStack
11. Check plugin loaded successfully and processed messages
12. Clean up all services

## Key Technical Details

### KCL 2.x Compatibility
The plugin has been updated to work with KCL v2.7.2, which includes:
- **ByteBuffer handling**: KCL 2.x returns read-only ByteBuffers that require proper byte copying
- **Endpoint configuration**: Support for custom kinesis_endpoint, dynamodb_endpoint, and cloudwatch_endpoint
- **Enhanced Fan-Out**: Uses RegisterStreamConsumer and SubscribeToShard APIs

### LocalStack Integration
Testing confirms the following work with LocalStack:
-  Kinesis endpoint override (`http://localstack:4566`)
- DynamoDB endpoint override for lease management
- CloudWatch endpoint override (when metrics enabled)
- Stream consumer registration
- Message retrieval via SubscribeToShard

## Running Tests

From the project root directory:

```bash
make integration
```

### With Real AWS Credentials

For full end-to-end testing with actual AWS services:

```bash
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret  
export AWS_REGION=us-east-1
# Comment out localstack service in docker-compose.yml
# Update kinesis_stream_name to real AWS stream
make integration
```

## Manual Testing

You can also run the services manually for debugging:

```bash
# Start services
docker compose up -d

# Send a test message
echo '{"test": "message"}' | docker compose exec -T localstack \
  aws --endpoint-url=http://localhost:4566 kinesis put-record \
  --stream-name test-logstash-stream \
  --partition-key test \
  --data "$(echo -n '{"test": "message"}' | base64)" \
  --region us-east-1

# Check logstash logs
docker compose logs -f logstash

# Check mock server requests
curl http://localhost:1080/mockserver/retrieve?type=REQUESTS

# Stop services
docker compose down -v
```

## Requirements

- Docker
- docker compose (v2 CLI)
- AWS CLI (for testing with localstack)
- jq (optional, for JSON parsing in output)

## Configuration Files

- `../docker-compose.yml`: Service definitions
- `logstash/pipeline/kinesis-test.conf`: Logstash pipeline configuration  
- `logstash/config/logstash.yml`: Logstash configuration
- `http-mock/expectations.json`: MockServer expectations
- `localstack/init.sh`: LocalStack initialization script
- `run-test.sh`: Main test runner script
- `check-requirements.sh`: Requirements checker

## Troubleshooting

### Services not starting
Check Docker logs:
```bash
docker compose logs
```

### Plugin installation fails
Check Logstash logs:
```bash
docker compose logs logstash
```

### Kinesis stream issues
Verify stream was created:
```bash
docker compose exec localstack aws --endpoint-url=http://localhost:4566 kinesis list-streams --region us-east-1
```

### Testing with Real AWS
To test with actual AWS Kinesis:
1. Set proper AWS credentials in environment
2. Remove or comment out the localstack service
3. Update the kinesis_stream_name to point to your AWS stream
4. Ensure AWS region matches your stream location
