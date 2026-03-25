# frozen_string_literal: true

module Binocs
  module ApplicationHelper
    def method_badge_class(method)
      case method.to_s.upcase
      when "GET"
        "bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/20"
      when "POST"
        "bg-cyan-500/15 text-cyan-400 ring-1 ring-cyan-500/20"
      when "PUT", "PATCH"
        "bg-amber-500/15 text-amber-400 ring-1 ring-amber-500/20"
      when "DELETE"
        "bg-rose-500/15 text-rose-400 ring-1 ring-rose-500/20"
      else
        "bg-zinc-800 text-zinc-400 ring-1 ring-zinc-700"
      end
    end

    def status_badge_class(status)
      return "bg-zinc-800 text-zinc-400 ring-1 ring-zinc-700" if status.nil?

      case status
      when 200..299
        "bg-emerald-500/15 text-emerald-400 ring-1 ring-emerald-500/20"
      when 300..399
        "bg-cyan-500/15 text-cyan-400 ring-1 ring-cyan-500/20"
      when 400..499
        "bg-amber-500/15 text-amber-400 ring-1 ring-amber-500/20"
      when 500..599
        "bg-rose-500/15 text-rose-400 ring-1 ring-rose-500/20"
      else
        "bg-zinc-800 text-zinc-400 ring-1 ring-zinc-700"
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
