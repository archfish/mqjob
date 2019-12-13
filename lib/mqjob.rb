require "mqjob/version"
require 'concurrent/executors'
require 'serverengine'
require 'mqjob/worker_group'
require 'mqjob/worker'
require 'plugin'

module Mqjob
  extend self

  attr_reader :config

  def configure(&block)
    @config ||= Config.new

    yield @config
  end

  def hooks
    @config.hooks
  end

  def default_client
    config.client
  end

  def registed_class
    @registed_class ||= []
  end

  def regist_class(v)
    @registed_class ||= []
    @registed_class << v
    @registed_class.uniq!
  end

  class Config
    attr_accessor :client,
                  :plugin,
                  :daemonize,
                  :workers,
                  :threads,
                  :hooks,
                  :logger,
                  :auto_ack,
                  :subscription_mode

    def initialize(opts = {})
      @hooks = Hooks.new(opts.delete(:hooks))
      @plugin = :pulsar

      assign_attributes(opts)

      remove_empty_instance_variables!

      require "plugin/#{@plugin}"
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
      attr_reader :before_fork, :after_fork

      def initialize(hooks)
        return if hooks.nil? || hooks.empty?

        @before_fork = hooks[:before_fork]
        @after_fork = hooks[:after_fork]
      end
    end
  end
end
