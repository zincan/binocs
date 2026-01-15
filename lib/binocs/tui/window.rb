# frozen_string_literal: true

module Binocs
  module TUI
    class Window
      attr_reader :win, :height, :width, :top, :left

      def initialize(height:, width:, top:, left:)
        @height = height
        @width = width
        @top = top
        @left = left
        @win = Curses::Window.new(height, width, top, left)
      end

      def refresh
        @win.refresh
      end

      def clear
        @win.clear
      end

      def close
        @win.close
      end

      def resize(height, width, top, left)
        @win.close
        @height = height
        @width = width
        @top = top
        @left = left
        @win = Curses::Window.new(height, width, top, left)
      end

      def draw_box(title = nil)
        @win.attron(Curses.color_pair(Colors::BORDER)) do
          # Draw corners
          @win.setpos(0, 0)
          @win.addstr('┌')
          @win.setpos(0, @width - 1)
          @win.addstr('┐')
          @win.setpos(@height - 1, 0)
          @win.addstr('└')
          @win.setpos(@height - 1, @width - 1)
          @win.addstr('┘')

          # Draw horizontal lines
          (1...@width - 1).each do |x|
            @win.setpos(0, x)
            @win.addstr('─')
            @win.setpos(@height - 1, x)
            @win.addstr('─')
          end

          # Draw vertical lines
          (1...@height - 1).each do |y|
            @win.setpos(y, 0)
            @win.addstr('│')
            @win.setpos(y, @width - 1)
            @win.addstr('│')
          end
        end

        # Draw title if provided
        if title
          @win.attron(Curses.color_pair(Colors::TITLE) | Curses::A_BOLD) do
            title_text = " #{title} "
            @win.setpos(0, 2)
            @win.addstr(title_text)
          end
        end
      end

      def write(y, x, text, color_pair = Colors::NORMAL, attrs = 0)
        return if y < 0 || y >= @height || x < 0

        @win.attron(Curses.color_pair(color_pair) | attrs) do
          @win.setpos(y, x)
          # Truncate text if it would overflow
          max_len = @width - x
          truncated = text.to_s[0, max_len]
          @win.addstr(truncated)
        end
      end

      def write_centered(y, text, color_pair = Colors::NORMAL, attrs = 0)
        x = [(@width - text.length) / 2, 0].max
        write(y, x, text, color_pair, attrs)
      end
    end
  end
end
