module Mqjob
  module Worker
    SUBSCRIPTION_MODES = [:exclusive, :failover, :shared].freeze

    def initialize(opts)
      @pool = opts[:pool]
      @topic = self.class.topic
      @topic_opts = self.class.topic_opts

      @mq = Plugin.client(@topic_opts[:client])
    end

    def ack!; :ack end
    def reject!; :reject; end
    def requeue!; :requeue; end

    def do_work(cmd, msg)
      @pool.post do
        Mqjob.logger.debug(__method__){'Begin post job to thread pool'}
        RequestStore.clear! if Object.const_defined?(:RequestStore)
        process_work(cmd, msg)
        Mqjob.logger.debug(__method__){'Finish post job to thread pool'}
      end
    end

    def run
      @mq.listen(@topic, self, @topic_opts)
    end

    def stop
      @mq.close_listen
    end

    def perform(msg); end

    private
    def process_work(cmd, msg)
      result = nil
      begin
        result = if respond_to?(:perform_full_msg)
          perform_full_msg(cmd, msg)
        else
          perform(msg.payload)
        end
      rescue => exp
        Mqjob.logger.error(__method__){exp}
        result = :error
      end

      case result
      when :error, :reject
        Mqjob.logger.info(__method__) {"Redeliver messages! Current message id is: #{msg.message_id.inspect}"}
        msg.nack
      when :requeue
        Mqjob.logger.info(__method__) {"Requeue! message id is: #{msg.message_id.inspect}"}
        self.class.enqueue(msg.payload, in: 10)
      else
        Mqjob.logger.info(__method__) {"Acknowledge message!"}
        msg.ack
      end
    end

    def self.included(base)
      base.extend ClassMethods
      ::Mqjob.regist_class(base) if base.is_a? Class
    end

    module ClassMethods
      attr_reader :topic_opts
      attr_reader :topic

      # client: MQ,
      # plugin: :pulsar,
      # prefetch: 1,
      # subscription_mode: SUBSCRIPTION_MODES, # 不同类型需要不同配置参数，互斥模式下需要指定订阅名
      # subscription_name
      # logger: MyLogger
      def from_topic(name, opts={})
        @topic = name
        @topic_opts = opts
      end

      # opts
      #   in publish message in X seconds
      #   at publish message at specific time
      def enqueue(msg, opts={})
        @mq ||= Plugin.client(topic_opts[:client])

        @mq.publish(topic, msg, topic_opts)
        true
      end
    end
  end
end
