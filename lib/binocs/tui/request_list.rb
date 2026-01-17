# frozen_string_literal: true

module Binocs
  module TUI
    class RequestList < Window
      attr_accessor :requests, :selected_index, :scroll_offset
      attr_reader :filters, :search_query

      def initialize(height:, width:, top:, left:)
        super
        @requests = []
        @selected_index = 0
        @scroll_offset = 0
        @filters = {}
        @search_query = nil
      end

      def load_requests
        scope = Binocs::Request.recent

        # Apply filters
        scope = scope.by_method(@filters[:method]) if @filters[:method].present?
        scope = scope.by_status_range(@filters[:status]) if @filters[:status].present?
        scope = scope.with_exception if @filters[:has_exception]
        scope = scope.search(@search_query) if @search_query.present?

        @requests = scope.limit(500).to_a

        # Adjust selection if out of bounds
        @selected_index = [@selected_index, @requests.length - 1].min
        @selected_index = 0 if @selected_index < 0

        adjust_scroll
      end

      def set_filter(key, value)
        if value.nil? || value == ''
          @filters.delete(key)
        else
          @filters[key] = value
        end
        load_requests
      end

      def set_search(query)
        @search_query = query.present? ? query : nil
        @selected_index = 0
        @scroll_offset = 0
        load_requests
      end

      def clear_filters
        @filters = {}
        @search_query = nil
        @selected_index = 0
        @scroll_offset = 0
        load_requests
      end

      def selected_request
        @requests[@selected_index]
      end

      def move_up
        if @selected_index > 0
          @selected_index -= 1
          adjust_scroll
        end
      end

      def move_down
        if @selected_index < @requests.length - 1
          @selected_index += 1
          adjust_scroll
        end
      end

      def go_to_top
        @selected_index = 0
        @scroll_offset = 0
      end

      def go_to_bottom
        @selected_index = [@requests.length - 1, 0].max
        adjust_scroll
      end

      def page_up
        visible_rows = content_height
        @selected_index = [@selected_index - visible_rows, 0].max
        adjust_scroll
      end

      def page_down
        visible_rows = content_height
        @selected_index = [@selected_index + visible_rows, @requests.length - 1].min
        adjust_scroll
      end

      def draw
        clear
        draw_box("Requests (#{@requests.length})")
        draw_header
        draw_requests
        draw_status_bar
        refresh
      end

      private

      def content_height
        @height - 5 # Box borders (2) + header (1) + status bar (2)
      end

      def content_width
        @width - 2 # Box borders
      end

      def adjust_scroll
        visible_rows = content_height

        # Scroll up if selected is above visible area
        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        end

        # Scroll down if selected is below visible area
        if @selected_index >= @scroll_offset + visible_rows
          @scroll_offset = @selected_index - visible_rows + 1
        end
      end

      def draw_header
        y = 1
        x = 1

        # Header - AI column + rest (leave room for time column ~10 chars)
        path_width = [content_width - 65, 15].max
        header = "AI METHOD  STATUS PATH#{' ' * (path_width - 4)} CONTROLLER                DURATION  TIME"
        write(y, x, header[0, content_width], Colors::HEADER, Curses::A_BOLD)

        # Draw separator
        write(2, 1, '─' * content_width, Colors::BORDER)
      end

      def draw_requests
        visible_rows = content_height
        start_y = 3

        visible_rows.times do |i|
          req_index = @scroll_offset + i
          break if req_index >= @requests.length

          request = @requests[req_index]
          y = start_y + i
          is_selected = req_index == @selected_index

          draw_request_row(y, request, is_selected)
        end
      end

      def draw_request_row(y, request, is_selected)
        if is_selected
          # Draw full-width selection background
          write(y, 1, ' ' * content_width, Colors::SELECTED)
        end

        x = 1

        # Agent indicator
        agents = Binocs::Agent.for_request(request.id)
        if agents.any?
          running = agents.any?(&:running?)
          indicator = running ? '●' : '○'
          color = running ? Colors::STATUS_SUCCESS : Colors::MUTED
          write(y, x, indicator, is_selected ? Colors::SELECTED : color, Curses::A_BOLD)
        end
        x += 3

        # Method (simple colored text for now)
        method_str = request.method.to_s.upcase.ljust(7)
        if is_selected
          write(y, x, method_str, Colors::SELECTED, Curses::A_BOLD)
        else
          write(y, x, method_str, Colors.method_color(request.method), Curses::A_BOLD)
        end
        x += 8

        # Status (simple colored text for now)
        status_str = (request.status_code || '???').to_s.ljust(6)
        if is_selected
          write(y, x, status_str, Colors::SELECTED)
        else
          write(y, x, status_str, Colors.status_color(request.status_code))
        end
        x += 7

        # Path (variable width - leave room for time column ~10 chars)
        path_width = [content_width - 65, 15].max
        path_text = truncate(request.path, path_width).ljust(path_width)
        write(y, x, path_text, is_selected ? Colors::SELECTED : Colors::NORMAL)
        x += path_width + 1

        # Controller
        controller_text = truncate(request.controller_action || '-', 25).ljust(25)
        write(y, x, controller_text, is_selected ? Colors::SELECTED : Colors::MUTED, is_selected ? 0 : Curses::A_DIM)
        x += 26

        # Duration
        duration_text = request.formatted_duration.ljust(8)
        write(y, x, duration_text, is_selected ? Colors::SELECTED : Colors::NORMAL)
        x += 9

        # Time
        time_text = time_ago(request.created_at)
        write(y, x, time_text, is_selected ? Colors::SELECTED : Colors::MUTED, is_selected ? 0 : Curses::A_DIM)

        # Exception indicator
        if request.has_exception?
          write(y, content_width - 2, '!', is_selected ? Colors::SELECTED : Colors::ERROR, Curses::A_BOLD)
        end
      end

      def draw_status_bar
        y = @height - 2

        # Draw separator
        write(y - 1, 1, '─' * content_width, Colors::BORDER)

        # Left side: filter info
        filter_parts = []
        filter_parts << "method:#{@filters[:method]}" if @filters[:method]
        filter_parts << "status:#{@filters[:status]}" if @filters[:status]
        filter_parts << "errors" if @filters[:has_exception]
        filter_parts << "search:\"#{@search_query}\"" if @search_query

        if filter_parts.any?
          filter_text = "Filters: #{filter_parts.join(', ')}"
          write(y, 1, truncate(filter_text, content_width / 2), Colors::MUTED, Curses::A_DIM)
        end

        # Right side: key hints
        hints = "j/k:nav  Enter:view  /:search  f:filter  r:refresh  ?:help  q:quit"
        write(y, content_width - hints.length, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def truncate(str, max_length)
        str = str.to_s
        return str if str.length <= max_length
        return str if max_length < 4

        "#{str[0, max_length - 3]}..."
      end

      def time_ago(time)
        return '-' unless time

        seconds = Time.current - time
        case seconds
        when 0..59 then "#{seconds.to_i}s ago"
        when 60..3599 then "#{(seconds / 60).to_i}m ago"
        when 3600..86399 then "#{(seconds / 3600).to_i}h ago"
        else "#{(seconds / 86400).to_i}d ago"
        end
      end
    end
  end
end
