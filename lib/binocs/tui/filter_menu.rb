# frozen_string_literal: true

module Binocs
  module TUI
    class FilterMenu < Window
      FILTERS = [
        { key: :method, label: 'HTTP Method', options: %w[GET POST PUT PATCH DELETE] },
        { key: :status, label: 'Status Code', options: %w[2xx 3xx 4xx 5xx] },
        { key: :has_exception, label: 'Has Exception', options: [true, false] },
      ].freeze

      attr_reader :selected_filters

      def initialize(height:, width:, top:, left:)
        super
        @selected_index = 0
        @selected_filters = {}
        @expanded_filter = nil
        @option_index = 0
      end

      def set_filters(filters)
        @selected_filters = filters.dup
      end

      def move_up
        if @expanded_filter
          @option_index = [@option_index - 1, 0].max
        else
          @selected_index = [@selected_index - 1, 0].max
        end
      end

      def move_down
        if @expanded_filter
          max = current_filter[:options].length
          @option_index = [@option_index + 1, max].min # +1 for "Clear" option
        else
          @selected_index = [@selected_index + 1, FILTERS.length - 1].min
        end
      end

      def select
        if @expanded_filter
          filter = current_filter
          if @option_index >= filter[:options].length
            # Clear option selected
            @selected_filters.delete(filter[:key])
          else
            value = filter[:options][@option_index]
            @selected_filters[filter[:key]] = value
          end
          @expanded_filter = nil
          @option_index = 0
        else
          @expanded_filter = @selected_index
          @option_index = 0
        end
      end

      def back
        if @expanded_filter
          @expanded_filter = nil
          @option_index = 0
          false
        else
          true
        end
      end

      def draw
        clear
        draw_box('Filters')

        y = 2

        FILTERS.each_with_index do |filter, i|
          is_selected = i == @selected_index && @expanded_filter.nil?
          is_expanded = i == @expanded_filter

          # Draw filter label
          label = "#{filter[:label]}: "
          current_value = @selected_filters[filter[:key]]
          value_text = current_value ? current_value.to_s : 'Any'

          if is_selected
            @win.attron(Curses.color_pair(Colors::SELECTED)) do
              @win.setpos(y, 2)
              @win.addstr(' ' * (@width - 4))
            end
            write(y, 3, label, Colors::SELECTED, Curses::A_BOLD)
            write(y, 3 + label.length, value_text, Colors::SELECTED)
            write(y, @width - 5, '▶', Colors::SELECTED)
          else
            write(y, 3, label, Colors::MUTED)
            color = current_value ? Colors::HEADER : Colors::MUTED
            write(y, 3 + label.length, value_text, color)
          end

          y += 1

          # Draw expanded options
          if is_expanded
            filter[:options].each_with_index do |option, oi|
              is_option_selected = oi == @option_index
              is_current = @selected_filters[filter[:key]] == option

              if is_option_selected
                @win.attron(Curses.color_pair(Colors::SELECTED)) do
                  @win.setpos(y, 4)
                  @win.addstr(' ' * (@width - 8))
                end
                write(y, 5, option.to_s, Colors::SELECTED)
                write(y, @width - 7, '✓', Colors::SELECTED) if is_current
              else
                color = is_current ? Colors::STATUS_SUCCESS : Colors::NORMAL
                write(y, 5, option.to_s, color)
                write(y, @width - 7, '✓', Colors::STATUS_SUCCESS) if is_current
              end
              y += 1
            end

            # Clear option
            is_clear_selected = @option_index >= filter[:options].length
            if is_clear_selected
              @win.attron(Curses.color_pair(Colors::SELECTED)) do
                @win.setpos(y, 4)
                @win.addstr(' ' * (@width - 8))
              end
              write(y, 5, '(Clear)', Colors::SELECTED)
            else
              write(y, 5, '(Clear)', Colors::MUTED, Curses::A_DIM)
            end
            y += 1
          end

          y += 1
          break if y >= @height - 4
        end

        # Footer
        draw_footer

        refresh
      end

      private

      def current_filter
        FILTERS[@expanded_filter || @selected_index]
      end

      def draw_footer
        y = @height - 2
        write(y - 1, 1, '─' * (@width - 2), Colors::BORDER)

        hints = @expanded_filter ? 'Enter:select  Esc:back' : 'Enter:expand  c:clear all  Esc:close'
        write(y, @width - hints.length - 2, hints, Colors::KEY_HINT, Curses::A_DIM)
      end
    end
  end
end
