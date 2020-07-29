module Mqjob
  class Message
    attr_reader :key, :body, :headers, :partition_key, :timestamp, :topic

    def initialize(
      key: nil, body:, topic:, headers: nil, partition_key: nil, timestamp: nil,
      ack_callback:, nack_callback:
    )
      @key = key
      @body = body
      @topic = topic
      @headers = headers || {}
      @partition_key = partition_key
      @timestamp = timestamp

      @ack_callback = ack_callback
      @nack_callback = nack_callback
      @retry_times = 0

      validate!
    end

    def validate!
      unless headers.nil? || headers.is_a?(Hash)
        raise "headers expected nil or Hash, but got #{headers.class}, value #{headers.inspect}"
      end
    end

    def retry!
      @retry_times += 1
    end

    def retried
      @retry_times
    end

    def nack
      @nack_callback.call
    end

    def ack
      @ack_callback.call
    end
  end
end
