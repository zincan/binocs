# frozen_string_literal: true

require 'json'

module Binocs
  class AgentContext
    class << self
      def build(request)
        sections = []

        sections << build_overview(request)
        sections << build_params(request)
        sections << build_headers(request)
        sections << build_body(request)
        sections << build_response(request)
        sections << build_logs(request)
        sections << build_exception(request)

        sections.compact.join("\n\n")
      end

      private

      def build_overview(request)
        # Use read_attribute for 'method' to avoid conflict with Object#method
        http_method = request.respond_to?(:read_attribute) ? request.read_attribute(:method) : request.method
        <<~SECTION
          ## Request Overview

          - **Method**: #{http_method || 'N/A'}
          - **Path**: #{request.path || 'N/A'}
          - **Full URL**: #{request.try(:full_url) || 'N/A'}
          - **Controller**: #{request.controller_name || 'N/A'}
          - **Action**: #{request.action_name || 'N/A'}
          - **Status Code**: #{request.status_code || 'N/A'}
          - **Duration**: #{request.try(:formatted_duration) || 'N/A'}
          - **IP Address**: #{request.ip_address || 'N/A'}
          - **Timestamp**: #{request.created_at&.iso8601 || 'N/A'}
        SECTION
      end

      def build_params(request)
        params = request.params
        return nil if params.blank?

        <<~SECTION
          ## Request Parameters

          ```json
          #{JSON.pretty_generate(params)}
          ```
        SECTION
      end

      def build_headers(request)
        sections = []

        req_headers = request.request_headers
        if req_headers.present?
          sections << <<~SECTION
            ## Request Headers

            ```json
            #{JSON.pretty_generate(req_headers)}
            ```
          SECTION
        end

        res_headers = request.response_headers
        if res_headers.present?
          sections << <<~SECTION
            ## Response Headers

            ```json
            #{JSON.pretty_generate(res_headers)}
            ```
          SECTION
        end

        sections.any? ? sections.join("\n\n") : nil
      end

      def build_body(request)
        body = request.request_body
        return nil if body.blank?

        formatted_body = format_body(body)

        <<~SECTION
          ## Request Body

          ```
          #{formatted_body}
          ```
        SECTION
      end

      def build_response(request)
        body = request.response_body
        return nil if body.blank?

        formatted_body = format_body(body)

        <<~SECTION
          ## Response Body

          ```
          #{formatted_body}
          ```
        SECTION
      end

      def build_logs(request)
        logs = request.logs
        return nil if logs.blank?

        log_lines = logs.map do |log|
          case log['type']
          when 'controller'
            "[#{log['timestamp']}] #{log['controller']}##{log['action']} - #{log['duration']}ms"
          when 'redirect'
            "[#{log['timestamp']}] Redirect to #{log['location']} (#{log['status']})"
          else
            "[#{log['timestamp']}] #{log['type']}: #{log.except('timestamp', 'type').to_json}"
          end
        end

        <<~SECTION
          ## Request Logs

          ```
          #{log_lines.join("\n")}
          ```
        SECTION
      end

      def build_exception(request)
        exc = request.exception
        return nil if exc.blank?

        backtrace = exc['backtrace']&.first(15)&.join("\n") || 'No backtrace'

        <<~SECTION
          ## Exception

          - **Class**: #{exc['class']}
          - **Message**: #{exc['message']}

          ### Backtrace

          ```
          #{backtrace}
          ```
        SECTION
      end

      def format_body(body)
        # Try to pretty-print JSON
        JSON.pretty_generate(JSON.parse(body))
      rescue JSON::ParserError
        body
      end
    end
  end
end
