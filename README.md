### Deployment

This project does not have continuous deployment enabled. To deploy manually 

- Commit a bump to `VERSION`
- Deploy [riff-raff project](https://riffraff.gutools.co.uk/deployment/history?projectName=deploy::logstash-input-kinesis&stage=INFRA)
- Change [amigo recipe to use the new version] and bake a new AMI
- Redeploy [the central ELK stack](https://riffraff.gutools.co.uk/deployment/history?projectName=central-elk&page=1)


### Run against real AWS Kinesis

1. Edit `integration-test/logstash/pipeline/kinesis-real-aws.conf` with your stream name, region, and (optionally) `role_arn`.

2. Build the Docker image:

```sh
make real-aws
```

3. Export AWS credentials and start the container:

```sh
eval $(aws configure export-credentials --profile <your-profile> --format env) \
  && docker compose -f docker-compose.real-aws.yml up -d
```

> **Important:** The `eval ... export-credentials` command sets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` as environment variables in your shell. The compose file forwards these to the container. If you skip this step or your credentials have expired, the container will fail to authenticate with AWS.

4. Follow the logs:

```sh
docker compose -f docker-compose.real-aws.yml logs -f
```

5. Stop and clean up:

```sh
docker compose -f docker-compose.real-aws.yml down
```

> **Tip:** After code changes, re-run `make real-aws` to rebuild the image. For pipeline config changes only, just restart the container — the config is mounted as a volume.

### Extract the built `.gem` file

```sh
# Build just the builder stage
docker build --target builder-kinesis -t logstash-kinesis-builder .

# Create a temporary container and copy the gem out
docker create --name gem-extract logstash-kinesis-builder
docker cp gem-extract:/build/logstash-input-kinesis-3.0.0-java.gem output/
docker rm gem-extract
```

The gem will be at `output/logstash-input-kinesis-3.0.0-java.gem`.


For the full README, see the original project https://github.com/logstash-plugins/logstash-input-kinesis
