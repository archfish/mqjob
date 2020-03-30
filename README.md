# Mqjob

A fast background processing framework for Ruby using MQ. MQ client was support as plugin. Current only implement Apache Pulsar. Name `Mqjob` was combine MQ and job.

Inspired By [Sneakers](https://github.com/jondot/sneakers).

## Examples

- [initializer](examples/initializers.rb)
- [rake task](examples/mqjob.rake)
- [Single Job](examples/single_job.rb)
- [Multiple Job](examples/multiple_job.rb)
- Shell run `WORKERS=SingleJob,MultipleJob bundle exec rake mqjob:run`

## API

### Global Config

  using in `Mqjob.configure`.

  - client

    An MQ client instance using in plugin. It should provide `producer` and `consumer` create api.

  - plugin

    Which implementing a specific MQ operations. Must implement basic interface:

    ```ruby
    def listen(topic, worker, opts = {}); end

    def publish(topic, msg, opts = {}); end
    ```

    See [Pulsar](lib/plugin/pulsar.rb) for detail.

  - daemonize

    Config worker run to background.

  - threads

    How many Thread will create for job perform in process. It will init a thread pool.
    IO-intensive tasks can be appropriately increased, and CPU-intensive tasks can be appropriately reduced.

  - hooks

    config `before_fork` and `after_fork`. NOT implement yet.
    if you using ActiveRecord, set `wrap_perform` as follow avoid database connection broken.

    ```ruby
    Mqjob.configure do |config|
      config.hooks = {
        wrap_perform: lambda {|&b| ActiveRecord::Base.connection_pool.with_connection {b.call}}
      }
    end
    ```

  - subscription_mode

    * exclusive

      Same subscription name only one conumser can subscribe to a topic.

    * failover

      All subscribe to a topic only one can receive message, once the subscribe exit the remain pick one keep up.

    * shared

      All subscribe can receive message.

  - logger

    A log instance implement Ruby std logger interface.

### Worker Config

  - client

    Using difference MQ client for this job. If connect to different types MQ you should config plugin at the same time.

  - plugin

    Using difference MQ client implement.

  - prefetch

    Config how many message per worker pull in one job cycle.

  - subscription_mode

    If set to `exclusive`, should provide subscription_name at the same time.

  - subscription_name

    Config subscription name, effects associated with subscription_mode.

  - logger

    Using difference logger for current worker.

  - topic_type

    * normal

      Ordinary topic name. Default value.

    * regex

      The topic name is a regex, represent topics which match this regex. For example, `persistent://my-tenant/namespace2/topic_*` is all topics in namespace2 that match `/topic_*/`.

## Note

- Thread pool will not clean `Thread.current` when thread give back to pool. If you want to use thread storage [RequestStore](https://github.com/steveklabnik/request_store) recommended, it build in support.
- database pool should not less than `threads` size.
- Maybe you should use connection pool to manage database connection. Like PgBouncer for PostgreSQL, Druid for MySQL.
- When topic_type is regex, message enqueue is not supported.
