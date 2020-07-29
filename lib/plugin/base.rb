module Plugin
  class Base
    attr_reader :client

    def initialize(c)
      @client = c
      @subscription_mode = ::Mqjob.config.subscription_mode
    end

    def listen(topic, worker, opts = {}); end

    def publish(topic, msg, opts = {}); end

    def close_listen; end
    def close_publish; end
  end
end
