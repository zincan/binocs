# frozen_string_literal: true

module Binocs
  class LogSubscriber < ActiveSupport::LogSubscriber
    def process_action(event)
      return unless Thread.current[:binocs_logs]

      payload = event.payload

      Thread.current[:binocs_logs] << {
        type: "controller",
        controller: payload[:controller],
        action: payload[:action],
        format: payload[:format],
        method: payload[:method],
        path: payload[:path],
        status: payload[:status],
        view_runtime: payload[:view_runtime]&.round(2),
        db_runtime: payload[:db_runtime]&.round(2),
        duration: event.duration.round(2),
        timestamp: Time.current.iso8601
      }

      # Capture exception info from the payload if present
      if payload[:exception_object]
        ex = payload[:exception_object]
        Thread.current[:binocs_logs] << {
          type: "exception",
          class: ex.class.name,
          message: ex.message,
          backtrace: ex.backtrace&.first(30),
          cause: exception_cause_chain(ex),
          timestamp: Time.current.iso8601
        }
      elsif payload[:exception]
        Thread.current[:binocs_logs] << {
          type: "exception",
          class: payload[:exception].first,
          message: payload[:exception].second,
          timestamp: Time.current.iso8601
        }
      end
    end

    def halted_callback(event)
      return unless Thread.current[:binocs_logs]

      Thread.current[:binocs_logs] << {
        type: "halted",
        filter: event.payload[:filter],
        timestamp: Time.current.iso8601
      }
    end

    def send_data(event)
      return unless Thread.current[:binocs_logs]

      Thread.current[:binocs_logs] << {
        type: "send_data",
        filename: event.payload[:filename],
        timestamp: Time.current.iso8601
      }
    end

    def redirect_to(event)
      return unless Thread.current[:binocs_logs]

      Thread.current[:binocs_logs] << {
        type: "redirect",
        location: event.payload[:location],
        status: event.payload[:status],
        timestamp: Time.current.iso8601
      }
    end

    private

    def exception_cause_chain(ex, depth = 0)
      return nil if ex.cause.nil? || depth >= 5

      cause = ex.cause
      {
        class: cause.class.name,
        message: cause.message,
        backtrace: cause.backtrace&.first(10),
        cause: exception_cause_chain(cause, depth + 1)
      }
    end
  end

  # Captures ActiveRecord SQL queries during a request
  class SqlLogSubscriber < ActiveSupport::LogSubscriber
    # Only capture queries that are meaningful for debugging
    IGNORED_QUERIES = %w[SCHEMA EXPLAIN].freeze

    def sql(event)
      return unless Thread.current[:binocs_logs]

      payload = event.payload
      return if IGNORED_QUERIES.include?(payload[:name])
      return if payload[:name] == "CACHE"

      entry = {
        type: "sql",
        name: payload[:name] || "SQL",
        sql: truncate_sql(payload[:sql]),
        duration: event.duration.round(2),
        timestamp: Time.current.iso8601
      }

      # Flag queries that are likely part of an error
      if payload[:exception]
        entry[:error] = true
        entry[:exception_class] = payload[:exception].first
        entry[:exception_message] = payload[:exception].second
      end

      Thread.current[:binocs_logs] << entry
    end

    private

    def truncate_sql(sql)
      return nil if sql.nil?

      sql = sql.squish
      sql.length > 2000 ? "#{sql[0, 2000]}..." : sql
    end
  end

  # Captures ActionView template and partial renders
  class ViewLogSubscriber < ActiveSupport::LogSubscriber
    def render_template(event)
      record_render(event, "template")
    end

    def render_partial(event)
      record_render(event, "partial")
    end

    def render_layout(event)
      record_render(event, "layout")
    end

    private

    def record_render(event, render_type)
      return unless Thread.current[:binocs_logs]

      payload = event.payload
      identifier = payload[:identifier]
      # Make the path relative to Rails root for readability
      if identifier && defined?(Rails.root)
        identifier = identifier.sub("#{Rails.root}/", "")
      end

      entry = {
        type: "render",
        render_type: render_type,
        identifier: identifier,
        duration: event.duration.round(2),
        timestamp: Time.current.iso8601
      }

      if payload[:exception]
        entry[:error] = true
        entry[:exception_class] = payload[:exception].first
        entry[:exception_message] = payload[:exception].second
      end

      Thread.current[:binocs_logs] << entry
    end
  end

  # Intercepts Rails.logger output during a request to capture log lines
  class LogInterceptor < Logger
    def initialize(original_logger)
      @original_logger = original_logger
      super(nil)
      self.level = original_logger.level
      self.formatter = original_logger.formatter
    end

    def add(severity, message = nil, progname = nil, &block)
      # Always pass through to original logger
      @original_logger.add(severity, message, progname, &block)

      # Capture to binocs logs if we're in a request context and severity >= WARN
      if Thread.current[:binocs_logs] && severity && severity >= Logger::WARN
        msg = message || (block ? block.call : progname)
        return true if msg.nil? || msg.to_s.strip.empty?

        level_name = case severity
                     when Logger::WARN then "warn"
                     when Logger::ERROR then "error"
                     when Logger::FATAL then "fatal"
                     else "unknown"
                     end

        Thread.current[:binocs_logs] << {
          type: "log",
          level: level_name,
          message: msg.to_s[0, 4000],
          timestamp: Time.current.iso8601
        }
      end

      true
    end

    # Delegate everything else to the original logger
    def method_missing(method, *args, &block)
      @original_logger.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @original_logger.respond_to?(method, include_private) || super
    end
  end
end
