namespace :mqjob do
  task run: :environment do
    workers = if ENV['WORKERS'].nil?
      Mqjob.registed_class
    else
      ENV['WORKERS'].split(',').map{|x| x.is_a?(String) ? x.constantize : x}
    end

    if workers.empty?
      puts "No workers found. Using format 「WORKERS=FooWorker,BarWorker bundle exec rake mqjob:run」"
      exit(1)
    end

    threads = ENV['THREAD_SIZE'].to_i
    threads = threads.zero? ? 10 : threads

    db_pool_size = ActiveRecord::Base.connection_pool.size
    if threads > db_pool_size
      puts "WARN: threads size #{threads}, but database pool size is #{db_pool_size}!!"
    end

    pidfile = ENV['PIDFILE']

    se = ServerEngine.create(
      nil,
      ::Mqjob::WorkerGroup.configure(threads: threads, clazz: workers),
      daemonize: Mqjob.daemonize,
      pid_path: pidfile
    )

    se.run
  end
end
