# Mqjob

## 例子

```ruby
require "bundler/setup"
require "mqjob"

Mqjob.configure do |config|
  config.threads = 3

  opts = PulsarSdk::Options::Connection.new(logical_addr: 'pulsar://pulsar.reocar.lan')
  config.client = PulsarSdk::Client.create(opts)
end

class MyWorker
  include ::Mqjob::Worker
  from_topic 'topic-01', subscription_mode: :shared

  def perform(msg)
    puts "#{self.class.name} => #{msg}"

    ack!
  end
end

se = ServerEngine.create(nil, ::Mqjob::WorkerGroup.configure(threads: 2, clazz: MyWorker), daemonize: false)

se.run
```

## 注意事项

- 线程使用前后记得清理Thread.current，推荐直接使用RequestStore
- 数据库连接池应当跟线程数匹配或稍等多1
- 因线程数通常设置得比较大，直连数据库可能会把数据库连接数用光，建议使用额外连接池如PgBouncer
