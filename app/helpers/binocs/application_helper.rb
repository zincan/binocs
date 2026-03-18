# frozen_string_literal: true

module Binocs
  module ApplicationHelper
    def method_badge_class(method)
      case method.to_s.upcase
      when "GET"
        "bg-green-900/50 text-green-300"
      when "POST"
        "bg-blue-900/50 text-blue-300"
      when "PUT", "PATCH"
        "bg-yellow-900/50 text-yellow-300"
      when "DELETE"
        "bg-red-900/50 text-red-300"
      else
        "bg-slate-700 text-slate-300"
      end
    end

    def status_badge_class(status)
      return "bg-slate-700 text-slate-300" if status.nil?

      case status
      when 200..299
        "bg-green-900/50 text-green-300"
      when 300..399
        "bg-blue-900/50 text-blue-300"
      when 400..499
        "bg-yellow-900/50 text-yellow-300"
      when 500..599
        "bg-red-900/50 text-red-300"
      else
        "bg-slate-700 text-slate-300"
      end
    end

    def format_value(value)
      case value
      when Hash, Array
        JSON.pretty_generate(value)
      when nil
        "null"
      else
        value.to_s
      end
    rescue
      value.to_s
    end

    def client_label(identifier)
      return "Unknown" if identifier.blank?

      prefix, value = identifier.split(":", 2)
      case prefix
      when "session" then "Session #{value.to_s[0, 8]}"
      when "auth" then "Auth #{value.to_s[0, 8]}"
      when "ip" then "IP #{value}"
      else identifier
      end
    end

    def format_body(body)
      return body if body.nil?

      begin
        parsed = JSON.parse(body)
        JSON.pretty_generate(parsed)
      rescue JSON::ParserError
        body
      end
    end

    def relative_time(time)
      return "N/A" if time.nil?

      seconds = (Time.current - time).to_i
      return "just now" if seconds < 5

      minutes = seconds / 60
      hours = minutes / 60

      if hours >= 3
        time.strftime("%b %d, %H:%M:%S")
      elsif hours >= 1
        "#{hours} #{hours == 1 ? 'hour' : 'hours'} ago"
      elsif minutes >= 1
        "#{minutes} #{minutes == 1 ? 'minute' : 'minutes'} ago"
      else
        "#{seconds} #{seconds == 1 ? 'second' : 'seconds'} ago"
      end
    end
  end
end
