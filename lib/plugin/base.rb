module Plugin
  class Base
    def initialize(client)
      @client = client
    end

    def listen(topic, worker, opts = {}); end

    def publish(topic, msg, opts = {}); end

    def close_listen; end
    def close_publish; end
  end
end
