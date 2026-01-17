# frozen_string_literal: true

module Binocs
  module TUI
    class AgentOutput < Window
      attr_accessor :agent, :scroll_offset, :auto_scroll

      def initialize(height:, width:, top:, left:)
        super
        @agent = nil
        @scroll_offset = 0
        @auto_scroll = true
        @output_lines = []
        @last_read_size = 0
      end

      def set_agent(agent)
        @agent = agent
        @scroll_offset = 0
        @auto_scroll = true
        @output_lines = []
        @last_read_size = 0
        load_output
      end

      def load_output
        return unless @agent

        output = @agent.output
        @output_lines = output.split("\n")

        # Auto-scroll to bottom if enabled
        if @auto_scroll
          max_scroll = [@output_lines.length - content_height, 0].max
          @scroll_offset = max_scroll
        end
      end

      def scroll_up
        @auto_scroll = false
        @scroll_offset = [@scroll_offset - 1, 0].max
      end

      def scroll_down
        max_scroll = [@output_lines.length - content_height, 0].max
        @scroll_offset = [@scroll_offset + 1, max_scroll].min
        @auto_scroll = @scroll_offset == max_scroll
      end

      def page_up
        @auto_scroll = false
        @scroll_offset = [@scroll_offset - content_height, 0].max
      end

      def page_down
        max_scroll = [@output_lines.length - content_height, 0].max
        @scroll_offset = [@scroll_offset + content_height, max_scroll].min
        @auto_scroll = @scroll_offset == max_scroll
      end

      def go_to_top
        @auto_scroll = false
        @scroll_offset = 0
      end

      def go_to_bottom
        max_scroll = [@output_lines.length - content_height, 0].max
        @scroll_offset = max_scroll
        @auto_scroll = true
      end

      def draw
        return unless @agent

        clear
        draw_box(build_title)
        draw_output
        draw_status_bar
        refresh
      end

      private

      def content_height
        @height - 4
      end

      def content_width
        @width - 4
      end

      def build_title
        status = @agent.status.to_s.upcase
        tool = @agent.tool.to_s
        "Agent Output [#{tool}] - #{status}"
      end

      def draw_output
        start_y = 1
        visible_rows = content_height

        if @output_lines.empty?
          write(start_y + 2, 2, "No output yet...", Colors::MUTED)
          if @agent.running?
            write(start_y + 3, 2, "Agent is running, waiting for output.", Colors::MUTED)
          end
          return
        end

        visible_rows.times do |i|
          line_index = @scroll_offset + i
          break if line_index >= @output_lines.length

          line = @output_lines[line_index] || ''
          y = start_y + i

          # Truncate long lines
          display_line = line.length > content_width ? "#{line[0, content_width - 1]}…" : line

          # Color code based on content
          color = line_color(line)
          write(y, 2, display_line, color)
        end
      end

      def draw_status_bar
        y = @height - 2

        write(y - 1, 1, '─' * (@width - 2), Colors::BORDER)

        # Left: scroll info
        total = @output_lines.length
        visible_end = [@scroll_offset + content_height, total].min
        scroll_info = "Lines #{@scroll_offset + 1}-#{visible_end} of #{total}"
        scroll_info += " [AUTO-SCROLL]" if @auto_scroll
        write(y, 2, scroll_info, Colors::MUTED, Curses::A_DIM)

        # Right: hints
        hints = "j/k:scroll  g/G:top/bottom  r:refresh  q/Esc:back"
        write(y, @width - hints.length - 2, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def line_color(line)
        case line
        when /error|Error|ERROR|exception|Exception/i
          Colors::ERROR
        when /warning|Warning|WARN/i
          Colors::STATUS_CLIENT_ERROR
        when /success|Success|completed|Completed/i
          Colors::STATUS_SUCCESS
        when /^[+]/
          Colors::STATUS_SUCCESS  # Git diff add
        when /^[-]/
          Colors::STATUS_SERVER_ERROR  # Git diff remove
        when /^@@/
          Colors::STATUS_REDIRECT  # Git diff hunk header
        else
          Colors::NORMAL
        end
      end
    end
  end
end
