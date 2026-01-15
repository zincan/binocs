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
  end
end
