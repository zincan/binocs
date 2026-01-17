# frozen_string_literal: true

module Binocs
  module TUI
    class AgentsList < Window
      attr_accessor :selected_index, :scroll_offset

      def initialize(height:, width:, top:, left:)
        super
        @selected_index = 0
        @scroll_offset = 0
      end

      def agents
        @agents ||= []
      end

      def load_agents
        @agents = Binocs::Agent.all.sort_by(&:created_at).reverse
        @selected_index = [@selected_index, @agents.length - 1].min
        @selected_index = 0 if @selected_index < 0
        adjust_scroll
      end

      def selected_agent
        agents[@selected_index]
      end

      def move_up
        if @selected_index > 0
          @selected_index -= 1
          adjust_scroll
        end
      end

      def move_down
        if @selected_index < agents.length - 1
          @selected_index += 1
          adjust_scroll
        end
      end

      def go_to_top
        @selected_index = 0
        @scroll_offset = 0
      end

      def go_to_bottom
        @selected_index = [agents.length - 1, 0].max
        adjust_scroll
      end

      def draw
        clear
        draw_box("Agents (#{agents.length} total, #{Binocs::Agent.running_count} running)")
        draw_header
        draw_agents
        draw_status_bar
        refresh
      end

      private

      def content_height
        @height - 5
      end

      def content_width
        @width - 2
      end

      def adjust_scroll
        visible_rows = content_height

        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        end

        if @selected_index >= @scroll_offset + visible_rows
          @scroll_offset = @selected_index - visible_rows + 1
        end
      end

      def draw_header
        y = 1
        x = 1

        header = "STATUS     TOOL        PROMPT                              DURATION  BRANCH"
        write(y, x, header[0, content_width], Colors::HEADER, Curses::A_BOLD)

        write(2, 1, '─' * content_width, Colors::BORDER)
      end

      def draw_agents
        visible_rows = content_height
        start_y = 3

        if agents.empty?
          write(start_y + 2, 2, "No agents running. Press 'Esc' to go back.", Colors::MUTED)
          write(start_y + 4, 2, "To launch an agent:", Colors::MUTED)
          write(start_y + 5, 2, "1. View a request (Enter)", Colors::MUTED)
          write(start_y + 6, 2, "2. Go to Agent tab (9)", Colors::MUTED)
          write(start_y + 7, 2, "3. Press Enter to compose prompt", Colors::MUTED)
          return
        end

        visible_rows.times do |i|
          agent_index = @scroll_offset + i
          break if agent_index >= agents.length

          agent = agents[agent_index]
          y = start_y + i
          is_selected = agent_index == @selected_index

          draw_agent_row(y, agent, is_selected)
        end
      end

      def draw_agent_row(y, agent, is_selected)
        if is_selected
          write(y, 1, ' ' * content_width, Colors::SELECTED)
        end

        x = 1

        # Status
        status_text = format_status(agent.status).ljust(10)
        status_color = status_color_for(agent.status)
        if is_selected
          write(y, x, status_text, Colors::SELECTED, Curses::A_BOLD)
        else
          write(y, x, status_text, status_color, Curses::A_BOLD)
        end
        x += 11

        # Tool
        tool_text = agent.tool.to_s.ljust(11)
        write(y, x, tool_text, is_selected ? Colors::SELECTED : Colors::MUTED)
        x += 12

        # Prompt (truncated)
        prompt_width = [content_width - 55, 20].max
        prompt_text = agent.short_prompt(prompt_width).ljust(prompt_width)
        write(y, x, prompt_text, is_selected ? Colors::SELECTED : Colors::NORMAL)
        x += prompt_width + 2

        # Duration
        duration_text = (agent.duration || '-').ljust(9)
        write(y, x, duration_text, is_selected ? Colors::SELECTED : Colors::MUTED)
        x += 10

        # Branch (short)
        branch_text = truncate_branch(agent.branch_name)
        write(y, x, branch_text, is_selected ? Colors::SELECTED : Colors::MUTED, Curses::A_DIM)
      end

      def draw_status_bar
        y = @height - 2

        write(y - 1, 1, '─' * content_width, Colors::BORDER)

        hints = "Enter:view output  d:delete  o:open folder  r:refresh  Esc:back"
        write(y, content_width - hints.length, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def format_status(status)
        case status
        when :pending then 'PENDING'
        when :running then 'RUNNING'
        when :completed then 'DONE'
        when :failed then 'FAILED'
        when :stopped then 'STOPPED'
        else status.to_s.upcase
        end
      end

      def status_color_for(status)
        case status
        when :running then Colors::STATUS_REDIRECT  # Yellow
        when :completed then Colors::STATUS_SUCCESS  # Blue/teal
        when :failed then Colors::STATUS_SERVER_ERROR  # Red
        when :stopped then Colors::STATUS_CLIENT_ERROR  # Magenta
        else Colors::MUTED
        end
      end

      def truncate_branch(branch)
        return '-' unless branch

        short = branch.sub('agent/', '')
        short.length > 20 ? "#{short[0, 17]}..." : short
      end
    end
  end
end
