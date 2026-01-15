# frozen_string_literal: true

require "securerandom"

module Binocs
  module Middleware
    class RequestRecorder
      def initialize(app)
        @app = app
      end

      def call(env)
        return @app.call(env) unless Binocs.enabled?
        return @app.call(env) if ignored_path?(env["PATH_INFO"])

        request_id = SecureRandom.uuid
        Thread.current[:binocs_request_id] = request_id
        Thread.current[:binocs_logs] = []
        Thread.current[:binocs_start_time] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Thread.current[:binocs_memory_before] = get_memory_usage

        request = ActionDispatch::Request.new(env)

        recorded_request = build_request_record(request, request_id)

        begin
          status, headers, response = @app.call(env)

          complete_request_record(recorded_request, status, headers, response, env)

          [status, headers, response]
        rescue Exception => e
          record_exception(recorded_request, e)
          raise
        ensure
          save_request_record(recorded_request)
          cleanup_thread_locals
        end
      end

      private

      def ignored_path?(path)
        Binocs.configuration.ignored_paths.any? { |ignored| path.start_with?(ignored) }
      end

      def build_request_record(request, request_id)
        {
          uuid: request_id,
          method: request.request_method,
          path: request.path,
          full_url: request.original_url,
          params: sanitize_params(request),
          request_headers: extract_headers(request.headers),
          ip_address: request.remote_ip,
          session_id: request.session.id&.to_s,
          content_type: request.content_type,
          request_body: extract_request_body(request)
        }
      end

      def complete_request_record(record, status, headers, response, env)
        record[:status_code] = status
        record[:response_headers] = headers.to_h
        record[:response_body] = extract_response_body(response, headers)
        record[:duration_ms] = calculate_duration
        record[:memory_delta] = calculate_memory_delta
        record[:logs] = Thread.current[:binocs_logs] || []
        record[:controller_name] = env["action_controller.instance"]&.class&.name
        record[:action_name] = env["action_controller.instance"]&.action_name
        record[:route_name] = extract_route_name(env)
      end

      def record_exception(record, exception)
        record[:exception] = {
          class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.first(20)
        }
        record[:status_code] ||= 500
        record[:duration_ms] = calculate_duration
        record[:memory_delta] = calculate_memory_delta
        record[:logs] = Thread.current[:binocs_logs] || []
      end

      def save_request_record(record)
        return unless record[:status_code]

        Binocs::Request.create!(
          uuid: record[:uuid],
          method: record[:method],
          path: record[:path],
          full_url: record[:full_url],
          controller_name: record[:controller_name],
          action_name: record[:action_name],
          route_name: record[:route_name],
          params: record[:params],
          request_headers: record[:request_headers],
          response_headers: record[:response_headers],
          request_body: record[:request_body],
          response_body: record[:response_body],
          status_code: record[:status_code],
          duration_ms: record[:duration_ms],
          ip_address: record[:ip_address],
          session_id: record[:session_id],
          logs: record[:logs],
          exception: record[:exception],
          memory_delta: record[:memory_delta]
        )

        broadcast_new_request(record)
        cleanup_old_requests
      rescue => e
        Rails.logger.error "[Binocs] Failed to save request: #{e.message}"
      end

      def broadcast_new_request(record)
        return unless defined?(Turbo::StreamsChannel)

        request = Binocs::Request.find_by(uuid: record[:uuid])
        return unless request

        Turbo::StreamsChannel.broadcast_prepend_to(
          "binocs_requests",
          target: "requests-list",
          partial: "binocs/requests/request",
          locals: { request: request }
        )
      rescue => e
        Rails.logger.error "[Binocs] Failed to broadcast request: #{e.message}"
      end

      def cleanup_old_requests
        return unless rand < 0.01 # Only run 1% of the time

        max_requests = Binocs.configuration.max_requests
        retention_period = Binocs.configuration.retention_period

        Binocs::Request.where("created_at < ?", retention_period.ago).delete_all

        count = Binocs::Request.count
        if count > max_requests
          Binocs::Request.order(created_at: :asc).limit(count - max_requests).delete_all
        end
      rescue => e
        Rails.logger.error "[Binocs] Failed to cleanup old requests: #{e.message}"
      end

      def sanitize_params(request)
        params = request.filtered_parameters.except("controller", "action")
        params.deep_transform_values { |v| truncate_value(v) }
      rescue
        {}
      end

      def extract_headers(headers)
        result = {}
        headers.each do |key, value|
          next unless key.start_with?("HTTP_") || %w[CONTENT_TYPE CONTENT_LENGTH].include?(key)

          header_name = key.sub(/^HTTP_/, "").split("_").map(&:capitalize).join("-")
          result[header_name] = value.to_s
        end
        result.except("Cookie") # Don't store cookies for security
      end

      def extract_request_body(request)
        return nil unless Binocs.configuration.record_request_body
        return nil if ignored_content_type?(request.content_type)

        body = request.body.read
        request.body.rewind
        truncate_body(body)
      rescue
        nil
      end

      def extract_response_body(response, headers)
        return nil unless Binocs.configuration.record_response_body

        content_type = headers["Content-Type"]
        return nil if ignored_content_type?(content_type)

        body = ""
        response.each { |part| body << part.to_s }
        truncate_body(body)
      rescue
        nil
      end

      def ignored_content_type?(content_type)
        return true if content_type.nil?

        Binocs.configuration.ignored_content_types.any? do |ignored|
          content_type.to_s.include?(ignored)
        end
      end

      def extract_route_name(env)
        route = Rails.application.routes.recognize_path(
          env["PATH_INFO"],
          method: env["REQUEST_METHOD"]
        )
        "#{route[:controller]}##{route[:action]}"
      rescue
        nil
      end

      def truncate_value(value)
        return value unless value.is_a?(String)
        return value if value.length <= 1000

        "#{value[0, 1000]}... (truncated)"
      end

      def truncate_body(body)
        return nil if body.nil? || body.empty?

        max_size = Binocs.configuration.max_body_size
        if body.bytesize > max_size
          "#{body.byteslice(0, max_size)}... (truncated, #{body.bytesize} bytes total)"
        else
          body
        end
      end

      def calculate_duration
        start_time = Thread.current[:binocs_start_time]
        return nil unless start_time

        ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)
      end

      def get_memory_usage
        `ps -o rss= -p #{Process.pid}`.to_i * 1024 rescue 0
      end

      def calculate_memory_delta
        before = Thread.current[:binocs_memory_before]
        return nil unless before

        get_memory_usage - before
      end

      def cleanup_thread_locals
        Thread.current[:binocs_request_id] = nil
        Thread.current[:binocs_logs] = nil
        Thread.current[:binocs_start_time] = nil
        Thread.current[:binocs_memory_before] = nil
      end
    end
  end
end
