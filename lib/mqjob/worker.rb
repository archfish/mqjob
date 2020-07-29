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

    def do_work(msg)
      act = Proc.new do
        begin
          wrap_perform = ::Mqjob.hooks&.wrap_perform

          ::Mqjob.logger.debug(__method__){'Begin process'}

          if wrap_perform.nil?
            process_work(msg)
          else
            wrap_perform.call do
              process_work(msg)
            end
          end

          ::Mqjob.logger.debug(__method__){'Finish process'}
        rescue => exp
          ::Mqjob.logger.error(__method__){"message process error: #{exp.message}! msg: #{msg}"}
          ::Mqjob.logger.error(__method__){exp}
        end
      end

      return act.call if ::Mqjob.synchronize?

      @pool.post do
        act.call
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
    def process_work(msg)
      RequestStore.clear! if Object.const_defined?(:RequestStore)

      ::Mqjob.logger.info(__method__){"process_work: #{msg.inspect}"}
      begin
        result = if respond_to?(:perform_full_msg)
          perform_full_msg(msg)
        else
          perform(msg.body)
        end

        case result
        when :error, :reject
          ::Mqjob.logger.info(__method__) {"Redeliver messages! Current message id is: #{msg.message_id.inspect}"}
          msg.nack
        when :requeue
          ::Mqjob.logger.info(__method__) {"Requeue! message id is: #{msg.message_id.inspect}"}
          msg.ack
          self.class.enqueue(msg.payload, in: 10)
        else
          ::Mqjob.logger.info(__method__) {"Acknowledge message!"}
          msg.ack
        end
      rescue ::Mqjob::Exception::Retry
        if msg.retried < ::Mqjob.config&.max_retry_times.to_i
          msg.retry!
          retry
        end
      rescue => exp
        ::Mqjob.logger.error(__method__){exp}
        result = :error
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
      # topic_type [:normal, :regex] default normal
      def from_topic(name, opts={})
        @topic = name.respond_to?(:call) ? name.call : name
        @topic_opts = opts

        topic_type = @topic_opts[:topic_type]&.to_sym
        @topic_opts[:topic_type] = topic_type || :normal

        @topic_opts[:subscription_name] ||= (self.name.split('::') << 'Consumer').join
      end

      # opts
      #   in publish message in X seconds
      #   at publish message at specific time
      #   init_subscription Boolean 是否先初始化一个订阅
      #   perform_now Boolean 立即执行，通常用于测试环境减少流程
      def enqueue(msg, opts={})
        if topic_opts[:topic_type] != :normal
          ::Mqjob.logger.error(__method__){
            "message enqueue only support topic_type set to normal, but got 「#{topic_opts[:topic_type]}」! After action skipped!"
          }
          return false
        end

        if !opts[:perform_now]
          @mq ||= Plugin.client(topic_opts[:client])
          @mq.publish(topic, msg, topic_opts.merge(opts))
          return true
        end

        begin
          worker = self.new({})
          if worker.respond_to?(:perform)
            msg = JSON.parse(JSON.dump(msg))
            ::Mqjob.logger.info('perform message now'){msg.inspect}
            worker.send(:process_work, nil, OpenStruct.new(payload: msg))
          else
            ::Mqjob.logger.error('perform_now required 「perform」 method, 「perform_full_msg」not supported!')
          end
        rescue => exp
          ::Mqjob.logger.error("#{self.name} perform_now") {exp}
        end
        true
      end
    end
  end
end
