class MultipleJob
  include Mqjob::Worker

  from_topic ['persistent://my-tenant/namespace1/topic-2', 'persistent://my-tenant/namespace2/topic-2'],
            prefetch: 2,
            subscription_mode: :shared,
            threads: 2

  # msg: {payload: {before: {XXX: XXXX}, after: {XXXX: XXXXX}, srouce: {model: XXXXX}}, op: c/u/d, ts_ms: XXXX}
  def perform(msg)
    Mqjob.logger.debug("#{self.class}::#{__method__} receive msg"){msg}

    case msg.dig('payload', 'srouce', 'model')
    when 'Order'
      # Do your job here
    when 'User'
      # Do your job here
    else
      raise 'unknown model type'
    end

    # pick one for message acknowledgement
    # ack!
    # reject!

    ack!
  end
end
