module Mqjob
  module WorkerGroup
    def initialize
      @stoped = false
      # 统一线程池，防止数据库连接池不够用，推荐设置为10
      @pool = ::Mqjob::ThreadPool.new(threads)

      pull_job_size = [::Mqjob.parallel, threads].min
      @pull_pool = ::Mqjob::ThreadPool.new(pull_job_size)
    end

    def before_fork
      Mqjob.hooks.before_fork&.call
    end

    def run
      return if @stoped

      Mqjob.hooks.after_fork&.call

      workers.each do |worker|
        @pull_pool.post do
          worker.run
        end
      end
    end

    def stop
      workers.each{|wc| wc.stop}

      @stoped = true
    end

    def reload
      puts "call #{__method__}"
    end

    def after_start
      puts "call #{__method__}"
    end

    def workers
      @workers ||= worker_classes.map do |wc|
        wc.new(pool: @pool)
      end
    end

    # 设置线程数并返回新类型
    # opts
    #   threads 设置线程池大小
    def self.configure(opts)
      thread_size = opts[:threads]
      raise "threads was required!" if thread_size.to_i.zero?
      workers = Array(opts[:clazz])
      raise "clazz was required!" if workers.empty?

      md = Module.new
      md_name = "WorkerGroup#{md.object_id}".tr('-', '_')

      md.include(self)
      md.class_eval <<-RUBY, __FILE__, __LINE__+1
        def threads
          #{thread_size}
        end

        def worker_classes
          #{workers}
        end

        private :threads, :workers
      RUBY

      Mqjob.const_set(md_name, md)
    end
  end
end
