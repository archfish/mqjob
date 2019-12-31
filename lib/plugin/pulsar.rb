require 'pulsar_sdk'

module Plugin
  class Pulsar < Base
    def listen(topic, worker, opts = {})
      create_consumer(topic, opts).listen do |cmd, msg|
        Mqjob.logger.debug("#{self.class.name}::#{__method__}"){"receive msg: #{msg.payload}"}
        worker.do_work(cmd, msg)
      end
    end

    # opts
    #   in publish message in X seconds
    #   at publish message at specific time
    #   init_subscription Boolean
    def publish(topic, msg, opts = {})
      create_consumer(topic, opts) if opts[:init_subscription]

      base_cmd = ::Pulsar::Proto::BaseCommand.new(
        type: ::Pulsar::Proto::BaseCommand::Type::SEND,
        send: ::Pulsar::Proto::CommandSend.new(
          num_messages: 1
        )
      )

      get_timestamp = lambda {|v| (v.to_f * 1000).floor}

      deliver_at = case
                  when opts[:in]
                    Time.now.localtime + opts[:in].to_f
                  when opts[:at]
                    opts[:at]
                  else
                    Time.now.localtime
                  end

      metadata = ::Pulsar::Proto::MessageMetadata.new(
        deliver_at_time: get_timestamp.call(deliver_at)
      )
      p_msg = ::PulsarSdk::Producer::Message.new(msg, metadata)

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
        consumer_opts = ::PulsarSdk::Options::Consumer.new(
          topic: topic,
          subscription_type: (opts[:subscription_mode] || @subscription_mode).to_s.capitalize.to_sym,
          subscription_name: opts[:subscription_name],
          prefetch: opts[:prefetch] || 1,
          listen_wait: 0.1
        )

        Mqjob.logger.debug(__method__){consumer_opts.inspect}

        @client.subscribe(consumer_opts)
      end
    end

    def create_producer(topic, opts)
      @producer ||= begin
        producer_opts = ::PulsarSdk::Options::Producer.new(
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
