# encoding: utf-8
class LogStash::Inputs::Kinesis::Worker
  include Java::SoftwareAmazonKinesisProcessor::ShardRecordProcessor

  attr_reader(
    :checkpoint_interval,
    :codec,
    :decorator,
    :logger,
    :output_queue,
  )

  def initialize(*args)
    if !@constructed
      @codec, @output_queue, @decorator, @checkpoint_interval, @logger = args
      @next_checkpoint = Time.now - 600
      @constructed = true
    end
  end
  public :initialize

  def initialize_processor(initialization_input)
    @shard_id = initialization_input.shardId()
  end

  def process_records(process_records_input)
    process_records_input.records().each { |record| process_record(record) }
    
    if Time.now >= @next_checkpoint
      process_records_input.checkpointer().checkpoint()
      @next_checkpoint = Time.now + @checkpoint_interval
    end
  rescue => error
    @logger.error("Error processing records: #{error}")
  end

  def lease_lost(lease_lost_input)
    @logger.info("Lease lost for shard #{@shard_id}")
  end

  def shard_ended(shard_ended_input)
    @logger.info("Shard #{@shard_id} ended, checkpointing...")
    shard_ended_input.checkpointer().checkpoint()
  rescue => error
    @logger.error("Error checkpointing shard end: #{error}")
  end

  def shutdown_requested(shutdown_requested_input)
    @logger.info("Shutdown requested for shard #{@shard_id}")
    shutdown_requested_input.checkpointer().checkpoint()
  rescue => error
    @logger.error("Error checkpointing on shutdown: #{error}")
  end

  protected

  def process_record(record)
    # KCL 2.x returns a read-only ByteBuffer, so we need to copy the bytes
    byte_buffer = record.data()
    bytes = Java::byte[byte_buffer.remaining].new
    byte_buffer.get(bytes)
    raw = String.from_java_bytes(bytes)
    
    metadata = build_metadata(record)
    
    @codec.decode(raw) do |event|
      @decorator.call(event)
      event.set('@metadata', event.get('@metadata').merge(metadata))
      @output_queue << event
    end
  rescue => error
    @logger.error("Error processing record", :error => error.message, :backtrace => error.backtrace)
  end

  def build_metadata(record)
    metadata = Hash.new
    metadata['approximate_arrival_timestamp'] = record.approximateArrivalTimestamp().toEpochMilli()
    metadata['partition_key'] = record.partitionKey()
    metadata['sequence_number'] = record.sequenceNumber()
    metadata['sub_sequence_number'] = record.subSequenceNumber()
    metadata
  end
end
