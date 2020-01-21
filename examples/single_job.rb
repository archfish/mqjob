class SingleJob
  include Mqjob::Worker

  from_topic 'topic-1',
            prefetch: 2,
            subscription_mode: :failover,
            threads: 2

  def perform(msg)
    Mqjob.logger.debug("#{self.class}::#{__method__} receive msg"){msg}

    # Do your job here

    # pick one for message acknowledgement
    # ack!
    # reject!
    # requeue!

    ack!
  end

  # if you need to get more detail
  # def perform_full_msg(cmd, msg)
  #   message = msg.payload
  #   Mqjob.logger.debug("#{self.class}::#{__method__} receive cmd"){cmd}
  #   Mqjob.logger.debug("#{self.class}::#{__method__} receive msg"){message}

  #   # Do your job here

  #   ack!
  # end
end
