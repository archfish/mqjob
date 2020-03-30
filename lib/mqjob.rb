require 'logger'
require "mqjob/version"
require "mqjob/thread_pool"
require 'serverengine'
require 'mqjob/worker_group'
require 'mqjob/worker'
require 'plugin'
require 'concurrent/configuration'

module Mqjob
  extend self

  attr_reader :config

  def configure(&block)
    @config ||= Config.new

    yield @config
  end

  def hooks
    config&.hooks
  end

  def default_client
    config&.client
  end

  # FIXME when job inherit from parent job it will not appear here!!
  def registed_class
    @registed_class ||= []
  end

  def regist_class(v)
    @registed_class ||= []
    @registed_class << v
    @registed_class.uniq!
  end

  def logger
    config.logger ||= ::Logger.new(STDOUT).tap do |logger|
                        logger.formatter = Formatter.new
                      end
  end

  class Config
    attr_accessor :client,
                  :plugin,
                  :daemonize,
                  :threads,
                  :subscription_mode
    attr_reader :logger, :hooks

    def initialize(opts = {})
      @hooks = Hooks.new(opts.delete(:hooks))
      @plugin = :pulsar

      assign_attributes(opts)

      remove_empty_instance_variables!
    end

    def hooks=(v)
      @hooks.update(v)
    end

    def logger=(v)
      # fvcking Concurrent::Logging
      unless v.respond_to?(:call)
        v.class.class_eval <<-RUBY
          def call(level, progname, message, &block)
            add(level, message, progname, &block)
          end
        RUBY
      end
      @logger = v
      Concurrent.global_logger = v
    end

    def assign_attributes(opts)
      opts.each do |k, v|
        method = "#{k}="
        next unless self.respond_to?(method)
        self.public_send method, v
      end
    end

    private
    def remove_empty_instance_variables!
      instance_variables.each do |x|
        remove_instance_variable(x) if instance_variable_get(x).nil?
      end
    end

    class Hooks
      attr_reader :before_fork, :after_fork, :wrap_perform

      def initialize(opts)
        update(opts)
      end

      def update(opts)
        return if opts.nil? || opts.empty?

        raise "hooks shuld be a Proc map!" unless opts.values.all?{|x| x.nil? || x.is_a?(Proc)}

        @before_fork = opts[:before_fork]
        @after_fork = opts[:after_fork]
        @wrap_perform = opts[:wrap_perform]
      end
    end
  end

  class Formatter < ::Logger::Formatter
    def call(severity, timestamp, progname, msg)
      case msg
      when ::StandardError
        msg = [msg.message, msg&.backtrace].join(":\n")
      end

      super
    end
  end
end
