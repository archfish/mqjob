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

se = ServerEngine.create(
  nil,
  ::Mqjob::WorkerGroup.configure(threads: 2, clazz: MyWorker),
  daemonize: false,
  pid_path: Object.const_defined?(:Rails) ? 'tmp/pids/mqjob_1.pid' : nil
)

se.run
```

## 参数列表

  - client

    创建好连接的MQ实例。以pulsar为例需要实现 `subscribe` 和 `create_producer`方法，可以通过在plugin中自定义实现。详情看`lib/plugin/pulsar.rb`

  - plugin

    使用的MQ插件，不同MQ有不同的实现方式。默认实现了一个pulsar的，可以自己实现一个，必须实现以下两个接口
    ```ruby
    def listen(topic, worker, opts = {}); end

    def publish(topic, msg, opts = {}); end
    ```

  - daemonize

    是否以守护进程方式运行。生产环境时推荐设置为true，开发环境调试时推荐设置为false。

  - threads

    每个进程开启多少工作线程。需要调整数据连接池配置大于等于该值。IO密集型任务可以适当调大，CPU密集型任务适当调小。推荐设置为10。

  - parallel

    每个进程并行从MQ拉取消息的数量。该值可以提高消息拉取效率，默认值为2。以pulsar为例，0.1秒内没有拉到消息则轮到下一个job，当job数量为10时，轮流拉取一遍消息至少要1秒，设置该值为5时，最快只需要0.2秒，依此类推。

  - hooks

    before_fork和after_fork。（暂时没实现）

  - logger

    日志模块，需要实现ruby标准库logger的相关接口。

  - subscription_mode

    exclusive：排他模式，相同订阅名每个topic只能有一个订阅。
    failover：灾备模式，相同订阅名都可以订阅一个topic，但是只有一个订阅能收到消息；
    shared：共享模式，多个订阅同时消费消息

## 注意事项

- 线程使用前后记得清理Thread.current，推荐直接使用RequestStore
- 数据库连接池应当跟线程数匹配或稍等多1
- 因线程数通常设置得比较大，直连数据库可能会把数据库连接数用光，建议使用额外连接池如PgBouncer
