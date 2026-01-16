# frozen_string_literal: true

module Binocs
  module Swagger
    class PathMatcher
      class << self
        def find_operation(request)
          spec = Client.fetch_spec
          return nil unless spec && spec['paths']

          method = request.method.downcase
          path = normalize_path(request.path)

          spec['paths'].each do |spec_path, path_item|
            next unless path_item.is_a?(Hash)

            operation = path_item[method]
            next unless operation

            if path_matches?(path, spec_path)
              return build_operation_result(spec_path, method, operation, path_item, spec)
            end
          end

          nil
        end

        def build_swagger_ui_url(operation)
          return nil unless operation

          base_url = Binocs.configuration.swagger_ui_url
          return nil if base_url.blank?

          # Build full URL if needed
          unless base_url.start_with?('http://', 'https://')
            if defined?(Rails)
              host = Rails.application.routes.default_url_options[:host] || 'localhost'
              port = Rails.application.routes.default_url_options[:port] || 3000
              protocol = Rails.application.routes.default_url_options[:protocol] || 'http'
              base_url = "#{protocol}://#{host}:#{port}#{base_url}"
            else
              base_url = "http://localhost:3000#{base_url}"
            end
          end

          # Build anchor for Swagger UI
          # Format: #/{tag}/{operationId}
          # Example: #/Company%20Invitations/get_v1_companies__company_uuid__invitations
          tag = operation[:tags]&.first || 'default'
          encoded_tag = URI.encode_www_form_component(tag).gsub('+', '%20')

          if operation[:operation_id]
            "#{base_url}#/#{encoded_tag}/#{operation[:operation_id]}"
          else
            # Fallback: build operation ID from method and path
            # get /v1/companies/{company_uuid}/invitations -> get_v1_companies__company_uuid__invitations
            fallback_op_id = "#{operation[:method]}#{operation[:spec_path]}"
              .gsub('/', '_')
              .gsub(/[{}]/, '_')
              .gsub(/__+/, '__')
            "#{base_url}#/#{encoded_tag}/#{fallback_op_id}"
          end
        end

        private

        def normalize_path(path)
          # Remove query string and normalize
          path = path.split('?').first
          path = path.chomp('/')
          path = '/' if path.empty?
          path
        end

        def path_matches?(request_path, spec_path)
          # Convert spec path template to regex
          # /users/{id}/posts/{post_id} -> /users/[^/]+/posts/[^/]+
          pattern = spec_path.gsub(/\{[^}]+\}/, '[^/]+')
          pattern = "^#{pattern}$"

          Regexp.new(pattern).match?(request_path)
        end

        def build_operation_result(spec_path, method, operation, path_item, spec)
          {
            spec_path: spec_path,
            method: method,
            operation_id: operation['operationId'],
            summary: operation['summary'],
            description: operation['description'],
            tags: operation['tags'] || [],
            parameters: collect_parameters(operation, path_item),
            request_body: operation['requestBody'],
            responses: operation['responses'] || {},
            deprecated: operation['deprecated'] || false,
            security: operation['security'] || spec['security']
          }
        end

        def collect_parameters(operation, path_item)
          params = []

          # Path-level parameters
          if path_item['parameters'].is_a?(Array)
            params.concat(path_item['parameters'])
          end

          # Operation-level parameters
          if operation['parameters'].is_a?(Array)
            params.concat(operation['parameters'])
          end

          params.uniq { |p| "#{p['in']}-#{p['name']}" }
        end
      end
    end
  end
end
