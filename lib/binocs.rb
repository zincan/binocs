# frozen_string_literal: true

require "binocs/version"
require "binocs/configuration"
require "binocs/engine"

module Binocs
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def enabled?
      configuration.enabled && !Rails.env.production?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
