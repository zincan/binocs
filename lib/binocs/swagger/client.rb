# frozen_string_literal: true

require 'net/http'
require 'json'
require 'yaml'

module Binocs
  module Swagger
    class Client
      CACHE_TTL = 300 # 5 minutes

      class << self
        def fetch_spec
          return nil unless Binocs.configuration.swagger_enabled?

          if cached_spec_valid?
            @cached_spec
          else
            refresh_spec
          end
        end

        def clear_cache
          @cached_spec = nil
          @cache_time = nil
        end

        private

        def cached_spec_valid?
          @cached_spec && @cache_time && (Time.now - @cache_time) < CACHE_TTL
        end

        def refresh_spec
          spec_url = build_spec_url
          return nil unless spec_url

          begin
            response = fetch_with_redirects(spec_url)
            return nil unless response

            @cached_spec = parse_spec(response.body, response['content-type'])
            @cache_time = Time.now
            @cached_spec
          rescue StandardError => e
            Rails.logger.error("[Binocs] Failed to fetch Swagger spec: #{e.message}") if defined?(Rails)
            nil
          end
        end

        def fetch_with_redirects(url, limit = 5)
          return nil if limit == 0

          uri = URI(url)
          response = Net::HTTP.get_response(uri)

          case response
          when Net::HTTPSuccess
            response
          when Net::HTTPRedirection
            redirect_url = response['location']
            # Handle relative redirects
            redirect_url = URI.join(url, redirect_url).to_s unless redirect_url.start_with?('http')
            fetch_with_redirects(redirect_url, limit - 1)
          else
            nil
          end
        end

        def build_spec_url
          spec_path = Binocs.configuration.swagger_spec_url
          return nil if spec_path.blank?

          # If it's already a full URL, use it directly
          return spec_path if spec_path.start_with?('http://', 'https://')

          # Otherwise, build from Rails default_url_options or localhost
          if defined?(Rails)
            host = Rails.application.routes.default_url_options[:host] || 'localhost'
            port = Rails.application.routes.default_url_options[:port] || 3000
            protocol = Rails.application.routes.default_url_options[:protocol] || 'http'
            "#{protocol}://#{host}:#{port}#{spec_path}"
          else
            "http://localhost:3000#{spec_path}"
          end
        end

        def parse_spec(body, content_type)
          if content_type&.include?('yaml') || body.strip.start_with?('openapi:', 'swagger:')
            YAML.safe_load(body, permitted_classes: [Date, Time])
          else
            JSON.parse(body)
          end
        rescue StandardError
          nil
        end
      end
    end
  end
end
