# frozen_string_literal: true

module Binocs
  module TUI
    class HelpScreen < Window
      KEYBINDINGS = [
        ['Navigation', [
          ['j / ↓', 'Move down / Scroll down'],
          ['k / ↑', 'Move up / Scroll up'],
          ['g / Home', 'Go to top'],
          ['G / End', 'Go to bottom'],
          ['Ctrl+d / PgDn', 'Page down'],
          ['Ctrl+u / PgUp', 'Page up'],
        ]],
        ['Actions', [
          ['Enter / l', 'View request details'],
          ['h / Esc', 'Go back / Close'],
          ['n / p', 'Next/prev request (detail)'],
          ['d', 'Delete request'],
          ['D', 'Delete all requests'],
        ]],
        ['Tabs (Detail View)', [
          ['Tab / ] / L', 'Next tab'],
          ['Shift+Tab / [ / H', 'Previous tab'],
          ['1-7', 'Jump to tab by number'],
        ]],
        ['Filtering', [
          ['/', 'Search by path'],
          ['f', 'Open filter menu'],
          ['c', 'Clear all filters'],
        ]],
        ['Other', [
          ['r', 'Refresh list'],
          ['?', 'Toggle this help'],
          ['q', 'Quit'],
        ]],
      ].freeze

      def draw
        clear
        draw_box('Help - Keybindings')

        y = 2
        KEYBINDINGS.each do |section_name, bindings|
          # Section header
          write(y, 3, "── #{section_name} ", Colors::HEADER, Curses::A_BOLD)
          y += 1

          bindings.each do |key, description|
            # Key
            @win.attron(Curses.color_pair(Colors::KEY_HINT) | Curses::A_BOLD) do
              @win.setpos(y, 4)
              @win.addstr(key.ljust(16))
            end

            # Description
            write(y, 21, description, Colors::NORMAL)
            y += 1
          end

          y += 1
          break if y >= @height - 3
        end

        # Footer
        write(@height - 2, 3, 'Press ? or Esc to close', Colors::MUTED, Curses::A_DIM)

        refresh
      end
    end
  end
end
