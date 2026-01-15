# frozen_string_literal: true

require "turbo-rails"
require "stimulus-rails"

module Binocs
  class Engine < ::Rails::Engine
    isolate_namespace Binocs

    config.generators do |g|
      g.test_framework :rspec
      g.assets false
      g.helper false
    end

    initializer "binocs.middleware" do |app|
      next unless Binocs.enabled?

      require_relative "middleware/request_recorder"
      app.middleware.use Binocs::Middleware::RequestRecorder
    end

    initializer "binocs.log_subscriber" do
      next unless Binocs.enabled?

      require_relative "log_subscriber"
      Binocs::LogSubscriber.attach_to :action_controller
    end

    initializer "binocs.assets" do |app|
      next unless Binocs.enabled?

      app.config.assets.precompile += %w[binocs/application.css binocs/application.js] if app.config.respond_to?(:assets)
    end

    initializer "binocs.importmap", before: "importmap" do |app|
      next unless Binocs.enabled?
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
    end

    config.after_initialize do
      if Rails.env.production? && Binocs.configuration.enabled
        Rails.logger.warn "[Binocs] WARNING: Binocs is disabled in production for security reasons."
        Binocs.configuration.enabled = false
      end
    end
  end
end
