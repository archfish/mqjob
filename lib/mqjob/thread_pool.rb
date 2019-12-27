require 'concurrent/executors'

module Mqjob
  class ThreadPool < ::Concurrent::FixedThreadPool
    def initialize(num_threads, opts = {})
      super
      @job_finish = ConditionVariable.new
      @job_mutex = Mutex.new
    end

    # NOTE 使用非缓冲线程池，防止消息丢失
    def post(*args, &task)
      wait

      super
    end

    def ns_execute
      super

      @job_finish.signal
    end

    def shutdown
      super

      @job_finish.broadcast
    end

    def kill
      super

      @job_finish.broadcast
    end

    def wait
      @job_mutex.synchronize do
        while running? && (scheduled_task_count - completed_task_count >= max_length)
          @job_finish.wait(@job_mutex, 0.05)
        end
      end
    end
  end
end
