ARG LOGSTASH_VERSION=8.15.2
FROM logstash:${LOGSTASH_VERSION} AS builder-kinesis

USER root

# Set up environment to use Logstash's bundled tools
ENV JAVA_HOME=/usr/share/logstash/jdk
ENV PATH=/usr/share/logstash/vendor/jruby/bin:$JAVA_HOME/bin:$PATH
ENV LOGSTASH_SOURCE=1
ENV LOGSTASH_PATH=/usr/share/logstash

# Set working directory
WORKDIR /build

# Copy the gem source code
COPY . .

# Build gem using Logstash's JRuby
# Always download JARs in Docker to ensure consistent builds regardless of local state
RUN gem install bundler && \
    bundle install --with development && \
    bundle exec rake install_jars && \
    gem build logstash-input-kinesis.gemspec

# Run unit tests
FROM builder-kinesis AS unit-test
RUN bundle exec rspec

# Output the built gem to a mounted volume or final location

ARG LOGSTASH_VERSION=8.15.2
FROM logstash:${LOGSTASH_VERSION}
COPY --from=builder-kinesis /build/logstash-input-kinesis-*.gem /tmp/
RUN /usr/share/logstash/bin/logstash-plugin install /tmp/logstash-input-kinesis-*.gem
