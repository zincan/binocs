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
          ['Ctrl+d/n / PgDn', 'Page down'],
          ['Ctrl+u/p / PgUp', 'Page up'],
        ]],
        ['Actions', [
          ['Enter / l', 'View request details'],
          ['h / Esc', 'Go back / Close'],
          ['n / J', 'Next request (detail view)'],
          ['p / K', 'Prev request (detail view)'],
          ['d', 'Delete request'],
          ['D', 'Delete all requests'],
          ['a', 'View all agents (from list)'],
        ]],
        ['Tabs (Detail View)', [
          ['Tab / ] / L', 'Next tab'],
          ['Shift+Tab / [ / H', 'Previous tab'],
          ['1-8', 'Jump to tab by number'],
          ['a', 'Agent tab + start input'],
          ['c', 'Copy tab content to clipboard'],
          ['o', 'Open Swagger docs in browser'],
        ]],
        ['Agent Tab', [
          ['i / Enter', 'Start composing prompt'],
          ['j / k', 'Scroll output up/down'],
          ['t', 'Change AI tool (Claude/OpenCode)'],
          ['w', 'Toggle worktree mode'],
          ['s', 'Stop running agent'],
          ['Esc', 'Cancel input'],
        ]],
        ['Agents View', [
          ['Enter', 'Go to request Agent tab'],
          ['l', 'View raw log output'],
          ['d', 'Delete/cleanup agent'],
          ['o', 'Open worktree folder'],
          ['r', 'Refresh agents list'],
        ]],
        ['Filtering', [
          ['/', 'Search by path'],
          ['f', 'Open filter menu'],
          ['c', 'Clear all filters'],
        ]],
        ['Other', [
          ['r', 'Refresh list'],
          ['?', 'Toggle this help'],
          ['Space s', 'Spirit animal (detail view)'],
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
