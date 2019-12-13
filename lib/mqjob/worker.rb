module Mqjob
  module Worker
    SUBSCRIPTION_MODES = [:exclusive, :failover, :shared].freeze

    def initialize(opts)
      @pool = opts[:pool]
      @topic = self.class.topic
      @topic_opts = self.class.topic_opts

      @client = @topic_opts[:client] || Mqjob.default_client

      plugin_name = @topic_opts[:plugin] || Mqjob.config.plugin
      @mq = Plugin.const_get(plugin_name.to_s.capitalize).new(@client)
    end

    def ack!; :ack end
    def reject!; :reject; end
    def requeue!; :requeue; end

    def do_work(cmd, msg)
      @pool.post do
        RequestStore.clear! if Object.const_defined?(RequestStore)
        process_work(cmd, msg)
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
          # TODO 可能需要先反序列化
          perform(msg.payload)
        end
      rescue => _exp
        result = :error
      end

      return if !@topic_opts[:ack]

      case result
      when :error, :reject
        msg.nack
      when :requeue
        # TODO
      else
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
      # auto_ack: true,
      # logger: MyLogger,
      # threads: 4, # 每个线程创建一个subscription
      def from_topic(name, opts={})
        @topic = name
        @topic_opts = opts
        if opts.key?(:plugin)
          require "plugin/#{opts[:plugin]}"
        end
      end

      def enqueue(msg, opts={})
        @producer ||= ::Mqjob::Producer.new(topic_opts[:client])
        @producer.publish(topic, msg, topic_opts)
      end
    end
  end
end
