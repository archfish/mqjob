Mqjob.configure do |config|
  config.client = PulsarSdk.create_client(logical_addr: 'pulsar://pulsar.server.lan')
  config.plugin = :pulsar
  config.subscription_mode = :shared
  config.daemonize = false
  # you should set your logger
  # config.logger = Application.default_logger
end
