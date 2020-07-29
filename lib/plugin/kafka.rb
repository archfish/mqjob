require 'rdkafka'

module Plugin
  class Kafka < Base
    def listen(topic, worker, opts = {})
      begin
        consumer = create_consumer(topic, opts)
        consumer.each do |msg|
          ::Mqjob.logger.debug("#{self.class.name}::#{__method__}"){"receive msg: #{msg}"}
          message = ::Mqjob::Message.new(
            key: msg.key,
            topic: msg.topic,
            body: msg.payload,
            headers: msg.headers,
            # partition_key: msg.partition_key,
            timestamp: msg.timestamp,
            ack_callback: Proc.new{consumer.store_offset(msg); consumer.commit},
            nack_callback: Proc.new{consumer.seekEx(topic, msg.partition, msg.offset > 0 ? msg.offset-1 : 0 ); consumer.commit; raise ::Mqjob::Exception::Retry}
          )
          ::Mqjob.logger.debug("#{self.class.name}::#{__method__} Message"){message}
          worker.do_work(message)
        end
      rescue ::Rdkafka::RdkafkaError => ex
        ::Mqjob.logger.info("#{self.class.name}::#{__method__} error"){ex}
      end
    end

    def publish(topic, msg, opts = {})
      create_producer(topic, opts).produce(
        {
          topic: topic,
          payload: msg
        }.merge(
          opts.slice(:key, :partition, :partition_key, :timestamp, :headers)
        )
      ).wait&.error
    end

    private
    # opts
    #   group_id  String
    #   session_timeout_ms Integer
    #   max_poll_interval_ms Integer
    #   enable_auto_offset_store Boolean
    #   auto_offset_reset smallest, earliest, beginning, largest, latest, end, error
    def create_consumer(topic, opts)
      client['group.id'] = opts[:group_id] || opts[:subscription_name]
      client['group.instance.id'] = 1
      # Emit RD_KAFKA_RESP_ERR__PARTITION_EOF event whenever the consumer reaches the end of a partition.
      client['enable.partition.eof'] = false
      # Client group session and failure detection timeout.
      # The consumer sends periodic heartbeats (heartbeat.interval.ms)
      # to indicate its liveness to the broker.
      # If no hearts are received by the broker for a group member within the session timeout,
      # the broker will remove the consumer from the group and trigger a rebalance.
      # The allowed range is configured with the broker configuration properties
      # group.min.session.timeout.ms and group.max.session.timeout.ms.
      # Also see max.poll.interval.ms.
      client['session.timeout.ms'] = 10 * 60 * 1000
      # Maximum allowed time between calls to consume messages (e.g., rd_kafka_consumer_poll())
      # for high-level consumers. If this interval is exceeded the consumer is considered failed
      # and the group will rebalance in order to reassign the partitions to another consumer group member.
      # Warning: Offset commits may be not possible at this point.
      # Note: It is recommended to set enable.auto.offset.store=false for long-time processing applications
      # and then explicitly store offsets (using offsets_store()) after message processing,
      # to make sure offsets are not auto-committed prior to processing has finished.
      # The interval is checked two times per second. See KIP-62 for more information.
      client['max.poll.interval.ms'] = 10 * 60 * 1000
      # Automatically store offset of last message provided to application.
      # The offset store is an in-memory store of the next offset to (auto-)commit for each partition.
      client['enable.auto.offset.store'] = false
      client['enable.auto.commit'] = false

      client['auto.offset.reset'] = opts[:auto_offset_reset] || 'beginning'

      ::Mqjob.logger.debug(__method__){client}
      consumer = client.consumer
      consumer.subscribe(topic)
      consumer
    end

    def create_producer(topic, opts)
      client.producer
    end
  end
end
