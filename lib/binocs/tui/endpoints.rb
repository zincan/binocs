# frozen_string_literal: true

module Binocs
  module TUI
    class Endpoints < Window
      attr_reader :selected_index

      def initialize(height:, width:, top:, left:)
        super
        @endpoints = []
        @selected_index = 0
        @scroll_offset = 0
      end

      def load_data
        rows = Binocs::Request
          .group(:method, :path)
          .select(
            "method",
            "path",
            "COUNT(*) as hit_count",
            "AVG(duration_ms) as avg_duration",
            "MAX(duration_ms) as max_duration",
            "MIN(duration_ms) as min_duration",
            "MAX(created_at) as last_hit_at",
            "SUM(CASE WHEN status_code >= 500 THEN 1 ELSE 0 END) as error_count",
            "SUM(CASE WHEN status_code >= 400 AND status_code < 500 THEN 1 ELSE 0 END) as client_error_count"
          )
          .order(Arel.sql("MAX(created_at) DESC"))
          .to_a

        @endpoints = rows
        @selected_index = [@selected_index, @endpoints.length - 1].min
        @selected_index = 0 if @selected_index < 0
        adjust_scroll
      end

      def selected_endpoint
        @endpoints[@selected_index]
      end

      def move_down
        if @selected_index < @endpoints.length - 1
          @selected_index += 1
          adjust_scroll
        end
      end

      def move_up
        if @selected_index > 0
          @selected_index -= 1
          adjust_scroll
        end
      end

      def go_to_top
        @selected_index = 0
        @scroll_offset = 0
      end

      def go_to_bottom
        @selected_index = [@endpoints.length - 1, 0].max
        adjust_scroll
      end

      def page_down
        @selected_index = [@selected_index + visible_rows, @endpoints.length - 1].min
        adjust_scroll
      end

      def page_up
        @selected_index = [@selected_index - visible_rows, 0].max
        adjust_scroll
      end

      def draw
        clear
        draw_box("Endpoints (#{@endpoints.length})")
        draw_header
        draw_separator
        draw_endpoints
        draw_status_bar
      end

      def content_as_text
        lines = []
        lines << "METHOD  PATH#{' ' * 40}  HITS    AVG        MAX        ERR   LAST HIT"
        lines << "-" * 100
        @endpoints.each do |ep|
          total_errors = ep.error_count.to_i + ep.client_error_count.to_i
          last = ep.respond_to?(:last_hit_at) ? time_ago(ep.last_hit_at) : "-"
          lines << "%-7s %-50s %5d  %9s  %9s  %4s  %s" % [
            ep.method,
            ep.path,
            ep.hit_count,
            format_ms(ep.avg_duration.to_f),
            format_ms(ep.max_duration.to_f),
            total_errors > 0 ? total_errors.to_s : "-",
            last
          ]
        end
        lines.join("\n")
      end

      private

      def visible_rows
        @height - 5 # box (2) + header (1) + separator (1) + status bar (1)
      end

      def content_width
        @width - 2
      end

      def adjust_scroll
        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        end
        if @selected_index >= @scroll_offset + visible_rows
          @scroll_offset = @selected_index - visible_rows + 1
        end
      end

      def draw_header
        y = 1
        # Column layout: METHOD  PATH  HITS  [heatbar]  AVG  MAX  ERRORS  LAST HIT
        cols = header_columns
        header = cols.map { |label, w| label.ljust(w) }.join(" ")
        write(y, 1, header[0, content_width], Colors::HEADER, Curses::A_BOLD)
      end

      def draw_separator
        write(2, 1, "─" * content_width, Colors::BORDER)
      end

      def header_columns
        path_w = path_width
        [
          ["METHOD", 7],
          ["PATH", path_w],
          ["HITS", 6],
          ["", heatbar_width],  # heatbar column (no label)
          ["AVG", 9],
          ["MAX", 9],
          ["ERR", 5],
          ["LAST HIT", 10]
        ]
      end

      def path_width
        # Dynamically allocate remaining width after fixed columns
        fixed = 7 + 6 + heatbar_width + 9 + 9 + 5 + 10 + 8 # columns + spacers
        [content_width - fixed, 15].max
      end

      def heatbar_width
        [(@width * 0.15).to_i, 8].max
      end

      def max_hits
        @max_hits ||= @endpoints.map(&:hit_count).max || 1
      end

      def draw_endpoints
        # Reset cached max on each draw
        @max_hits = nil

        start_y = 3

        visible_rows.times do |i|
          ep_index = @scroll_offset + i
          break if ep_index >= @endpoints.length

          ep = @endpoints[ep_index]
          y = start_y + i
          is_selected = ep_index == @selected_index

          draw_endpoint_row(y, ep, is_selected)
        end
      end

      def draw_endpoint_row(y, ep, is_selected)
        if is_selected
          write(y, 1, " " * content_width, Colors::SELECTED)
        end

        x = 1
        path_w = path_width
        bar_w = heatbar_width

        # Method
        method_str = ep.method.to_s.upcase.ljust(7)
        if is_selected
          write(y, x, method_str, Colors::SELECTED, Curses::A_BOLD)
        else
          write(y, x, method_str, Colors.method_color(ep.method), Curses::A_BOLD)
        end
        x += 8

        # Path
        path_text = truncate(ep.path, path_w).ljust(path_w)
        write(y, x, path_text, is_selected ? Colors::SELECTED : Colors::NORMAL)
        x += path_w + 1

        # Hit count
        hits_str = ep.hit_count.to_s.rjust(5)
        write(y, x, hits_str, is_selected ? Colors::SELECTED : Colors::TITLE, Curses::A_BOLD)
        x += 7

        # Heat bar
        draw_heatbar(y, x, bar_w, ep.hit_count, is_selected)
        x += bar_w + 1

        # Avg duration
        avg_ms = ep.avg_duration.to_f
        avg_str = format_ms(avg_ms).rjust(8)
        avg_color = if is_selected then Colors::SELECTED
                    elsif avg_ms > 1000 then Colors::STATUS_SERVER_ERROR
                    elsif avg_ms > 500 then Colors::STATUS_CLIENT_ERROR
                    elsif avg_ms > 200 then Colors::METHOD_PUT
                    else Colors::STATUS_SUCCESS
                    end
        write(y, x, avg_str, avg_color)
        x += 10

        # Max duration
        max_ms = ep.max_duration.to_f
        max_str = format_ms(max_ms).rjust(8)
        write(y, x, max_str, is_selected ? Colors::SELECTED : Colors::MUTED, Curses::A_DIM)
        x += 10

        # Errors
        total_errors = ep.error_count.to_i + ep.client_error_count.to_i
        if total_errors > 0
          err_str = total_errors.to_s.rjust(4)
          write(y, x, err_str, is_selected ? Colors::SELECTED : Colors::ERROR, Curses::A_BOLD)
        else
          write(y, x, "   -", is_selected ? Colors::SELECTED : Colors::MUTED, Curses::A_DIM)
        end
        x += 6

        # Last hit
        last_hit = ep.respond_to?(:last_hit_at) ? ep.last_hit_at : nil
        time_str = time_ago(last_hit)
        write(y, x, time_str, is_selected ? Colors::SELECTED : Colors::MUTED, Curses::A_DIM)
      end

      def draw_heatbar(y, x, width, hits, is_selected)
        return if width < 2

        ratio = hits.to_f / max_hits
        filled = (ratio * width).ceil
        filled = [filled, 1].max if hits > 0

        # Determine color intensity based on ratio
        bar_color = if is_selected
                      Colors::SELECTED
                    elsif ratio > 0.75
                      Colors::METHOD_POST # bright blue
                    elsif ratio > 0.4
                      Colors::STATUS_SUCCESS # green/teal
                    elsif ratio > 0.15
                      Colors::METHOD_PUT # yellow
                    else
                      Colors::MUTED
                    end

        filled.times do |i|
          write(y, x + i, "█", bar_color)
        end
        (width - filled).times do |i|
          write(y, x + filled + i, "░", is_selected ? Colors::SELECTED : Colors::BORDER, Curses::A_DIM)
        end
      end

      def draw_status_bar
        y = @height - 2
        write(y - 1, 1, "─" * content_width, Colors::BORDER)

        # Left: info
        total_hits = @endpoints.sum(&:hit_count)
        info = "#{@endpoints.length} endpoints │ #{total_hits} total hits"
        info += " │ #{@selected_index + 1}/#{@endpoints.length}" if @endpoints.any?
        write(y, 2, info, Colors::MUTED, Curses::A_DIM)

        # Right: key hints
        hints = "j/k:nav  Enter:view  c:copy  r:refresh  Esc:back  ?:help"
        write(y, content_width - hints.length, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def truncate(str, max_length)
        str = str.to_s
        return str if str.length <= max_length
        return str if max_length < 4

        "#{str[0, max_length - 3]}..."
      end

      def format_ms(ms)
        if ms < 1
          "< 1ms"
        elsif ms < 1000
          "#{ms.round(1)}ms"
        else
          "#{(ms / 1000).round(2)}s"
        end
      end

      def time_ago(time)
        return "-" unless time

        # Handle string times from SQL
        time = Time.parse(time.to_s) unless time.is_a?(Time)

        seconds = (Time.current - time).to_i
        case seconds
        when 0..59 then "#{seconds}s ago"
        when 60..3599 then "#{(seconds / 60)}m ago"
        when 3600..86399 then "#{(seconds / 3600)}h ago"
        else "#{(seconds / 86400)}d ago"
        end
      rescue
        "-"
      end
    end
  end
end
