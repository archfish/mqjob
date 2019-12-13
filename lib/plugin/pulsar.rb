require 'pulsar_sdk'

module Plugin
  class Pulsar < Base
    def listen(topic, worker, opts = {})
      create_consumer(topic, opts).listen do |cmd, msg|
        worker.do_work(cmd, msg)
      end

      @consumer.close
    end

    def publish(topic, msg, opts = {})
      base_cmd = Pulsar::Proto::BaseCommand.new(
        type: Pulsar::Proto::BaseCommand::Type::SEND,
        send: Pulsar::Proto::CommandSend.new(
          num_messages: 1
        )
      )

      # FIXME encode first!
      p_msg = PulsarSdk::Producer::Message.new(msg)

      create_producer(topic, opts).execute_async(base_cmd, p_msg)
    end

    def close_listen
      @consumer&.close
    end

    def close_publish
      @producer&.close
    end

    private
    def create_consumer(topic, opts)
      @consumer ||= begin
        consumer_opts = PulsarSdk::Options::Consumer.new(
          topic: topic,
          prefetch: opts[:prefetch] || 1,
          listen_wait: 0.1
        )

        @client.subscribe(consumer_opts)
      end
    end

    def create_producer(topic, opts)
      @producer ||= begin
        producer_opts = PulsarSdk::Options::Producer.new(
          topic: topic
        )

        @client.create_producer(producer_opts)
      end
    end

  end
end

# NOTE
#   ServerEngine会自动循环调用，所以这里使用无阻塞listen即可
#   如果这里listen阻塞会导致同组任务无法正常执行
