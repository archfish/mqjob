require 'plugin/base'

module Plugin
  extend self

  def client(c, plugin: nil)
    plugin = init_plugin(plugin)
    c ||= Mqjob.default_client

    Plugin.const_get(plugin).new(c)
  end

  def init_plugin(name)
    name ||= Mqjob.config.plugin

    require "plugin/#{name}"

    name.to_s.capitalize
  end

  private :init_plugin
end
