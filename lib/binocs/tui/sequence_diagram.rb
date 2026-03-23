# frozen_string_literal: true

module Binocs
  module TUI
    class SequenceDiagram < Window
      attr_reader :selected_index, :client_index

      def initialize(height:, width:, top:, left:)
        super
        @requests = []
        @client_identifiers = []
        @client_index = 0
        @selected_index = 0
        @scroll_offset = 0
      end

      def load_data
        @client_identifiers = Binocs::Request.client_identifiers
        load_requests_for_current_client
      end

      def selected_request
        @requests[@selected_index]
      end

      def current_client
        @client_identifiers[@client_index]
      end

      def next_client
        return if @client_identifiers.empty?

        @client_index = (@client_index + 1) % @client_identifiers.length
        load_requests_for_current_client
      end

      def prev_client
        return if @client_identifiers.empty?

        @client_index = (@client_index - 1) % @client_identifiers.length
        load_requests_for_current_client
      end

      def move_down
        if @selected_index < @requests.length - 1
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
        @selected_index = [@requests.length - 1, 0].max
        adjust_scroll
      end

      def page_down
        @selected_index = [@selected_index + visible_rows, @requests.length - 1].min
        adjust_scroll
      end

      def page_up
        @selected_index = [@selected_index - visible_rows, 0].max
        adjust_scroll
      end

      def draw
        clear
        draw_box("Sequence Diagram")
        draw_client_selector
        draw_lifeline_headers
        draw_separator
        draw_requests
        draw_status_bar
      end

      def content_as_text
        lines = []
        lines << "Sequence Diagram - Client: #{client_label(current_client)}"
        lines << "=" * 80
        lines << ""
        @requests.each do |req|
          time = req.created_at&.strftime("%H:%M:%S.%L") || "?"
          lines << "  #{time}  #{req.method} #{req.path}"
          lines << "  #{' ' * 12}  ← #{req.status_code || '???'} #{req.formatted_duration}"
          lines << ""
        end
        lines.join("\n")
      end

      private

      def visible_rows
        # Each request takes 3 lines (request arrow, response arrow, spacer)
        (@height - 8) / 3
      end

      def content_width
        @width - 2
      end

      def load_requests_for_current_client
        @selected_index = 0
        @scroll_offset = 0

        client = current_client
        if client
          @requests = Binocs::Request.by_client(client).for_sequence.limit(200).to_a
        else
          @requests = []
        end
      end

      def adjust_scroll
        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        end
        if @selected_index >= @scroll_offset + visible_rows
          @scroll_offset = @selected_index - visible_rows + 1
        end
      end

      def draw_client_selector
        return if @client_identifiers.empty?

        label = client_label(current_client)
        count_text = "(#{@client_index + 1}/#{@client_identifiers.length})"
        text = "◀ [  #{label} #{count_text}  ] ▶"

        write(1, (@width - text.length) / 2, text, Colors::HEADER, Curses::A_BOLD)
      end

      def draw_lifeline_headers
        y = 2
        half = content_width / 2

        # Client header (left side)
        client_text = "Client"
        write(y, half / 2 - client_text.length / 2 + 1, client_text, Colors::METHOD_POST, Curses::A_BOLD)

        # Server header (right side)
        server_text = "Server"
        write(y, half + half / 2 - server_text.length / 2 + 1, server_text, Colors::STATUS_SUCCESS, Curses::A_BOLD)
      end

      def draw_separator
        y = 3
        half = content_width / 2

        # Lifeline markers
        write(y, half / 2 + 1, "│", Colors::METHOD_POST)
        write(y, half + half / 2 + 1, "│", Colors::STATUS_SUCCESS)

        # Horizontal separator
        (1...@width - 1).each do |x|
          next if x == half / 2 + 1 || x == half + half / 2 + 1
          write(y, x, "─", Colors::BORDER)
        end
      end

      def draw_requests
        start_y = 4
        half = content_width / 2
        client_x = half / 2 + 1
        server_x = half + half / 2 + 1

        visible_rows.times do |i|
          req_index = @scroll_offset + i
          break if req_index >= @requests.length

          request = @requests[req_index]
          y = start_y + (i * 3)
          is_selected = req_index == @selected_index

          break if y + 2 >= @height - 2

          # Draw lifelines
          3.times do |dy|
            write(y + dy, client_x, "│", Colors::METHOD_POST, Curses::A_DIM)
            write(y + dy, server_x, "│", Colors::STATUS_SUCCESS, Curses::A_DIM)
          end

          # Selection highlight
          if is_selected
            (client_x..server_x).each { |x| write(y, x, " ", Colors::SELECTED) }
          end

          # Request arrow (Client -> Server): ────────────────▶
          arrow_start = client_x + 1
          arrow_end = server_x - 1
          arrow_width = arrow_end - arrow_start

          method_color = is_selected ? Colors::SELECTED : Colors.method_color(request.method)
          (arrow_start..arrow_end - 1).each { |x| write(y, x, "─", method_color) }
          write(y, arrow_end, "▶", method_color)

          # Request label on the arrow line
          label = "#{request.method} #{truncate_path(request.path, arrow_width - 10)}"
          label_x = arrow_start + (arrow_width - label.length) / 2
          write(y, [label_x, arrow_start + 1].max, label, method_color, Curses::A_BOLD)

          # Response arrow (Server -> Client): ◀┄┄┄┄┄┄┄┄┄┄┄┄┄┄
          response_y = y + 1
          status_color = is_selected ? Colors::SELECTED : Colors.status_color(request.status_code)
          write(response_y, arrow_start, "◀", status_color)
          ((arrow_start + 1)..arrow_end).each { |x| write(response_y, x, "┄", status_color, Curses::A_DIM) }

          # Response label
          resp_label = "#{request.status_code || '???'} #{request.formatted_duration}"
          resp_label_x = arrow_start + (arrow_width - resp_label.length) / 2
          write(response_y, [resp_label_x, arrow_start + 2].max, resp_label, status_color)

          # Timestamp on the far right
          if request.created_at
            time_str = request.created_at.strftime("%H:%M:%S")
            write(y, @width - time_str.length - 2, time_str, Colors::MUTED, Curses::A_DIM)
          end
        end
      end

      def draw_status_bar
        y = @height - 2
        write(y - 1, 1, "─" * content_width, Colors::BORDER)

        # Left: request count
        info = "#{@requests.length} requests"
        info += " │ #{@selected_index + 1}/#{@requests.length}" if @requests.any?
        write(y, 2, info, Colors::MUTED, Curses::A_DIM)

        # Right: key hints
        hints = "[/]:client  j/k:nav  Enter:detail  Esc:back  ?:help"
        write(y, content_width - hints.length, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def client_label(identifier)
        return "No Clients" if identifier.nil?

        prefix, value = identifier.split(":", 2)
        case prefix
        when "session" then "Session #{value.to_s[0, 8]}"
        when "auth" then "Auth #{value.to_s[0, 8]}"
        when "ip" then "IP #{value}"
        else identifier
        end
      end

      def truncate_path(path, max_length)
        return path.to_s if path.to_s.length <= max_length
        return path.to_s if max_length < 4

        "#{path[0, max_length - 3]}..."
      end
    end
  end
end
