require 'logstash-core/logstash-core'
require 'logstash-input-kinesis_jars'
require "logstash/plugin"
require "logstash/inputs/kinesis"
require "logstash/codecs/json"
require "json"

RSpec.describe "LogStash::Inputs::Kinesis::Worker" do
  subject!(:worker) { LogStash::Inputs::Kinesis::Worker.new(codec, queue, decorator, checkpoint_interval, logger) }
  let(:codec) { LogStash::Codecs::JSON.new() }
  let(:queue) { Queue.new }
  let(:decorator) { proc { |x| x.set('decorated', true); x } }
  let(:checkpoint_interval) { 120 }
  let(:logger) { double('logger', info: nil, error: nil, warn: nil) }
  let(:checkpointer) { double('checkpointer', checkpoint: nil) }
  let(:init_input) { 
    double('initialization_input', shardId: 'shard-000001')
  }

  it "honors the initialize java interface method contract" do
    expect { worker.initialize_processor(init_input) }.to_not raise_error
  end

  def record(hash, arrival_timestamp, partition_key, sequence_number, sub_sequence_number = 0)
    hash ||= { "message" => "test" }
    encoder = java.nio.charset::Charset.forName("UTF-8").newEncoder()
    data_bytes = encoder.encode(java.nio.CharBuffer.wrap(JSON.generate(hash)))
    rec = double('record')
    allow(rec).to receive(:data).and_return(data_bytes)
    allow(rec).to receive(:approximateArrivalTimestamp).and_return(
      java.time.Instant.ofEpochMilli((arrival_timestamp.to_f * 1000).to_i)
    )
    allow(rec).to receive(:partitionKey).and_return(partition_key)
    allow(rec).to receive(:sequenceNumber).and_return(sequence_number)
    allow(rec).to receive(:subSequenceNumber).and_return(sub_sequence_number)
    rec
  end

  let(:process_input) {
    input = double('process_records_input')
    records = java.util.Arrays.asList([
      record(
        {
          id: "record1",
          message: "test1"
        },
        '1.441215410867E9',
        'partitionKey1',
        '21269319989652663814458848515492872191'
      ),
      record(
        {
          '@metadata' => {
            forwarded: 'record2'
          },
          id: "record2",
          message: "test2"
        },
        '1.441215410868E9',
        'partitionKey2',
        '21269319989652663814458848515492872192'
      )
    ].to_java)
    allow(input).to receive(:records).and_return(records)
    allow(input).to receive(:checkpointer).and_return(checkpointer)
    input
  }
  let(:collide_metadata_process_input) {
    input = double('process_records_input')
    records = java.util.Arrays.asList([
      record(
        {
          '@metadata' => {
            forwarded: 'record3',
            partition_key: 'invalid_key'
          },
          id: "record3",
          message: "test3"
        },
        '1.441215410869E9',
        'partitionKey3',
        '21269319989652663814458848515492872193'
      )
    ].to_java)
    allow(input).to receive(:records).and_return(records)
    allow(input).to receive(:checkpointer).and_return(checkpointer)
    input
  }
  let(:empty_process_input) {
    input = double('process_records_input')
    allow(input).to receive(:records).and_return(java.util.Arrays.asList([].to_java))
    allow(input).to receive(:checkpointer).and_return(checkpointer)
    input
  }

  context "initialized" do
    before do
      worker.initialize_processor(init_input)
    end

    describe "#process_records" do
      it "decodes and queues each record with decoration" do
        worker.process_records(process_input)
        expect(queue.size).to eq(2)
        m1 = queue.pop
        m2 = queue.pop
        expect(m1).to be_kind_of(LogStash::Event)
        expect(m2).to be_kind_of(LogStash::Event)
        expect(m1.get('id')).to eq("record1")
        expect(m1.get('message')).to eq("test1")
        expect(m1.get('@metadata')['approximate_arrival_timestamp']).to eq(1441215410867)
        expect(m1.get('@metadata')['partition_key']).to eq('partitionKey1')
        expect(m1.get('@metadata')['sequence_number']).to eq('21269319989652663814458848515492872191')
        expect(m1.get('decorated')).to eq(true)
      end

      it "decodes and keeps submitted metadata" do
        worker.process_records(process_input)
        expect(queue.size).to eq(2)
        m1 = queue.pop
        m2 = queue.pop
        expect(m1).to be_kind_of(LogStash::Event)
        expect(m2).to be_kind_of(LogStash::Event)
        expect(m1.get('@metadata')['forwarded']).to eq(nil)
        expect(m2.get('@metadata')['forwarded']).to eq('record2')
      end

      it "decodes and does not allow submitted metadata to overwrite internal keys" do
        worker.process_records(collide_metadata_process_input)
        expect(queue.size).to eq(1)
        m1 = queue.pop
        expect(m1).to be_kind_of(LogStash::Event)
        expect(m1.get('@metadata')['forwarded']).to eq('record3')
        expect(m1.get('@metadata')['partition_key']).to eq('partitionKey3')
      end

      it "checkpoints on interval" do
        expect(checkpointer).to receive(:checkpoint).once
        worker.process_records(empty_process_input)

        # not this time
        worker.process_records(empty_process_input)

        allow(Time).to receive(:now).and_return(Time.now + 125)
        expect(checkpointer).to receive(:checkpoint).once
        worker.process_records(empty_process_input)
      end
    end

    describe "#shard_ended" do
      it "checkpoints on shard end" do
        input = double('shard_ended_input')
        allow(input).to receive(:checkpointer).and_return(checkpointer)
        expect(checkpointer).to receive(:checkpoint)
        worker.shard_ended(input)
      end
    end

    describe "#shutdown_requested" do
      it "checkpoints on shutdown request" do
        input = double('shutdown_requested_input')
        allow(input).to receive(:checkpointer).and_return(checkpointer)
        expect(checkpointer).to receive(:checkpoint)
        worker.shutdown_requested(input)
      end
    end
  end
end
