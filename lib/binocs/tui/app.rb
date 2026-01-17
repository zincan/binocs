# frozen_string_literal: true

module Binocs
  module TUI
    class App
      DEFAULT_REFRESH_INTERVAL = 2 # seconds

      attr_reader :running

      def initialize(options = {})
        @running = false
        @mode = :list # :list, :detail, :help, :filter, :search, :agents, :agent_output, :spirit_animal
        @last_refresh = Time.now
        @search_buffer = ''
        @refresh_interval = options[:refresh_interval] || DEFAULT_REFRESH_INTERVAL
        @agents_window = nil
        @agent_output_window = nil
        @spirit_animal_window = nil
        @last_key = nil # Track last key for combo detection
      end

      def run
        setup_curses
        create_windows
        load_data

        @running = true
        main_loop
      ensure
        cleanup
      end

      private

      def setup_curses
        Curses.init_screen
        Curses.start_color
        Curses.use_default_colors
        Curses.cbreak
        Curses.noecho
        Curses.curs_set(0) # Hide cursor
        Curses.stdscr.keypad(true)
        Curses.stdscr.timeout = 100 # Non-blocking getch with 100ms timeout

        Colors.init
        Curses.refresh # Required before creating windows for colors to work
      end

      def create_windows
        recalculate_layout
      end

      def recalculate_layout
        height = Curses.lines
        width = Curses.cols

        # Close overlay windows
        @help_window&.close
        @help_window = nil
        @filter_window&.close
        @filter_window = nil
        @agents_window&.close
        @agents_window = nil
        @agent_output_window&.close
        @agent_output_window = nil
        @spirit_animal_window&.close
        @spirit_animal_window = nil

        # Determine if we need split screen (detail view active)
        showing_detail = @mode == :detail ||
                         (@previous_mode == :detail && (@mode == :help || @mode == :filter || @mode == :spirit_animal))

        # Preserve list window state before potential recreation
        preserved_state = nil
        if @list_window
          preserved_state = {
            selected_index: @list_window.selected_index,
            scroll_offset: @list_window.scroll_offset,
            filters: @list_window.filters.dup,
            search_query: @list_window.search_query
          }
        end

        # Recreate main windows if dimensions changed or mode changed
        if showing_detail
          list_width = [width / 3, 40].max
          detail_width = width - list_width

          if @list_window.nil? || @list_window.width != list_width || @list_window.height != height
            @list_window&.close
            @list_window = RequestList.new(
              height: height,
              width: list_width,
              top: 0,
              left: 0
            )
            restore_list_state(preserved_state)
          end

          if @detail_window.nil? || @detail_window.width != detail_width || @detail_window.height != height
            @detail_window&.close
            @detail_window = RequestDetail.new(
              height: height,
              width: detail_width,
              top: 0,
              left: list_width
            )
          end
        else
          # Full width list
          @detail_window&.close
          @detail_window = nil

          if @list_window.nil? || @list_window.width != width || @list_window.height != height
            @list_window&.close
            @list_window = RequestList.new(
              height: height,
              width: width,
              top: 0,
              left: 0
            )
            restore_list_state(preserved_state)
          end
        end

        # Help overlay (centered)
        if @mode == :help
          help_height = [32, height - 4].min
          help_width = [65, width - 4].min
          @help_window = HelpScreen.new(
            height: help_height,
            width: help_width,
            top: (height - help_height) / 2,
            left: (width - help_width) / 2
          )
        end

        # Filter menu (centered overlay)
        if @mode == :filter
          filter_height = [20, height - 4].min
          filter_width = [40, width / 2].min
          @filter_window = FilterMenu.new(
            height: filter_height,
            width: filter_width,
            top: (height - filter_height) / 2,
            left: (width - filter_width) / 2
          )
          @filter_window.set_filters(@list_window.filters)
        end

        # Agents list (full screen)
        if @mode == :agents
          @agents_window = AgentsList.new(
            height: height,
            width: width,
            top: 0,
            left: 0
          )
          @agents_window.load_agents
        end

        # Agent output viewer (full screen)
        if @mode == :agent_output
          @agent_output_window = AgentOutput.new(
            height: height,
            width: width,
            top: 0,
            left: 0
          )
        end

        # Spirit animal overlay (centered popup)
        if @mode == :spirit_animal
          spirit_height = [25, height - 4].min
          spirit_width = [50, width - 4].min
          @spirit_animal_window = SpiritAnimal.new(
            height: spirit_height,
            width: spirit_width,
            top: (height - spirit_height) / 2,
            left: (width - spirit_width) / 2
          )
        end
      end

      def load_data
        @list_window.load_requests
      end

      def main_loop
        while @running
          handle_resize if Curses.cols != @last_cols || Curses.lines != @last_lines
          @last_cols = Curses.cols
          @last_lines = Curses.lines

          draw
          handle_input

          # Auto-refresh in list mode
          if @mode == :list && Time.now - @last_refresh > @refresh_interval
            load_data
            @last_refresh = Time.now
          end

          # Auto-refresh agents list and output
          if @mode == :agents && Time.now - @last_refresh > @refresh_interval
            @agents_window&.load_agents
            @last_refresh = Time.now
          end

          if @mode == :agent_output && Time.now - @last_refresh > 1 # Faster refresh for output
            @agent_output_window&.load_output
            @last_refresh = Time.now
          end

          # Auto-refresh Agent tab when agent is running
          if @mode == :detail && @detail_window&.agent_tab?
            agent = @detail_window.current_agent
            if agent&.running? && Time.now - @last_refresh > 1
              @detail_window.build_content
              @last_refresh = Time.now
            end
          end
        end
      end

      def handle_resize
        Curses.clear
        Curses.refresh
        recalculate_layout
        load_data if @list_window
      end

      def draw
        # Use noutrefresh for all windows, then doupdate once to reduce flicker
        case @mode
        when :list
          @list_window.draw
          @list_window.noutrefresh
        when :detail
          @list_window.draw
          @list_window.noutrefresh
          @detail_window.draw
          @detail_window.noutrefresh
        when :help
          @list_window.draw
          @list_window.noutrefresh
          @detail_window&.draw
          @detail_window&.noutrefresh
          @help_window.draw
          @help_window.noutrefresh
        when :filter
          @list_window.draw
          @list_window.noutrefresh
          @detail_window&.draw
          @detail_window&.noutrefresh
          @filter_window.draw
          @filter_window.noutrefresh
        when :search
          @list_window.draw
          @list_window.noutrefresh
          draw_search_bar
        when :agents
          @agents_window.draw
          @agents_window.noutrefresh
        when :agent_output
          @agent_output_window.draw
          @agent_output_window.noutrefresh
        when :spirit_animal
          @list_window.draw
          @list_window.noutrefresh
          @detail_window&.draw
          @detail_window&.noutrefresh
          @spirit_animal_window.draw
          @spirit_animal_window.noutrefresh
        end
        Curses.doupdate
      end

      def draw_search_bar
        width = Curses.cols
        y = Curses.lines - 1

        Curses.attron(Curses.color_pair(Colors::SEARCH)) do
          Curses.setpos(y, 0)
          Curses.addstr(' ' * width)
          Curses.setpos(y, 0)
          Curses.addstr("/#{@search_buffer}")
        end
        Curses.curs_set(1) # Show cursor
        Curses.setpos(y, @search_buffer.length + 1)
        Curses.refresh
      end

      def handle_input
        key = Curses.getch
        return unless key

        case @mode
        when :list then handle_list_input(key)
        when :detail then handle_detail_input(key)
        when :help then handle_help_input(key)
        when :filter then handle_filter_input(key)
        when :search then handle_search_input(key)
        when :agents then handle_agents_input(key)
        when :agent_output then handle_agent_output_input(key)
        when :spirit_animal then handle_spirit_animal_input(key)
        end
      end

      def handle_list_input(key)
        case key
        when 'q', 'Q'
          @running = false
        when 'j', Curses::KEY_DOWN
          @list_window.move_down
        when 'k', Curses::KEY_UP
          @list_window.move_up
        when 'g', Curses::KEY_HOME
          @list_window.go_to_top
        when 'G', Curses::KEY_END
          @list_window.go_to_bottom
        when Curses::KEY_NPAGE, 4, 14 # Ctrl+D, Ctrl+N
          @list_window.page_down
        when Curses::KEY_PPAGE, 21, 16 # Ctrl+U, Ctrl+P
          @list_window.page_up
        when Curses::KEY_ENTER, 10, 13, 'l'
          enter_detail_mode
        when '/'
          enter_search_mode
        when 'f'
          @previous_mode = :list
          @mode = :filter
          recalculate_layout
        when 'c'
          @list_window.clear_filters
          @last_refresh = Time.now
        when 'r'
          load_data
          @last_refresh = Time.now
        when '?'
          @previous_mode = :list
          @mode = :help
          recalculate_layout
        when 'd'
          delete_selected_request
        when 'D'
          delete_all_requests
        when 'a'
          enter_agents_mode
        end
      end

      def handle_detail_input(key)
        # First, let the Agent tab handle its own input
        if @detail_window&.agent_tab?
          handled = @detail_window.handle_agent_key(key)
          if handled
            # Refresh content if agent tab handled the input
            @detail_window.build_content if @detail_window.agent_tab?
            return
          end

          # If agent input or worktree input is active, don't process other keys
          if @detail_window.agent_input_active || @detail_window.agent_worktree_input_active
            return # Don't process other keys while typing
          end
        end

        case key
        when 'q', 'Q'
          @running = false
        when 'h', Curses::KEY_LEFT
          exit_detail_mode
        when 27 # Esc
          exit_detail_mode
        when 'j', Curses::KEY_DOWN
          @detail_window.scroll_down
        when 'k', Curses::KEY_UP
          @detail_window.scroll_up
        when Curses::KEY_NPAGE, 4, 14 # Ctrl+D, Ctrl+N
          @detail_window.page_down
        when Curses::KEY_PPAGE, 21, 16 # Ctrl+U, Ctrl+P
          @detail_window.page_up
        when 9, ']', 'L' # Tab, ], L - next tab
          @detail_window.next_tab
          update_cursor_visibility
        when 353, '[', 'H' # Shift+Tab, [, H - prev tab
          @detail_window.prev_tab
          update_cursor_visibility
        when '1' then @detail_window.go_to_tab(0) # Overview
        when '2' then @detail_window.go_to_tab(1) # Params
        when '3' then @detail_window.go_to_tab(2) # Headers
        when '4' then @detail_window.go_to_tab(3) # Body
        when '5' then @detail_window.go_to_tab(4) # Response
        when '6' then @detail_window.go_to_tab(5) # Logs
        when '7' then @detail_window.go_to_tab(6) # Exception
        when '8' then @detail_window.go_to_tab(7) # Swagger
        when '9', 'a'
          @detail_window.go_to_tab(8) # Agent
          @detail_window.agent_input_active = true
          Curses.curs_set(1)
        when 'o', 'O'
          open_swagger_in_browser
        when 'c'
          copy_tab_content
        when 'n', 'J' # Next request (n or Shift+J)
          @list_window.move_down
          update_detail_request
        when 'p', 'K' # Previous request (p or Shift+K)
          @list_window.move_up
          update_detail_request
        when '?'
          @previous_mode = :detail
          @mode = :help
          recalculate_layout
        when 'f'
          @previous_mode = :detail
          @mode = :filter
          recalculate_layout
        when 's'
          # Easter egg: spacebar + s shows spirit animal
          if @last_key == ' ' || @last_key == 32
            show_spirit_animal
          end
        when ' ', 32 # spacebar
          # Just track it for the combo
        end

        # Track last key for combos (spacebar + s)
        @last_key = key
      end

      def show_spirit_animal
        return unless @list_window.selected_request

        @previous_mode = :detail
        @mode = :spirit_animal
        recalculate_layout
        @spirit_animal_window.set_request(@list_window.selected_request)
      end

      def handle_spirit_animal_input(key)
        # Any key closes the spirit animal popup
        @mode = @previous_mode || :detail
        recalculate_layout
      end

      def copy_tab_content
        return unless @detail_window

        text = @detail_window.content_as_text
        if @detail_window.copy_to_clipboard(text)
          # Brief flash to indicate copy succeeded - could show a message
        end
      end

      def update_cursor_visibility
        if @detail_window&.agent_tab? && (@detail_window.agent_input_active || @detail_window.agent_worktree_input_active)
          Curses.curs_set(1)
        else
          Curses.curs_set(0)
        end
      end

      def handle_help_input(key)
        case key
        when '?', 27, 'q', Curses::KEY_ENTER, 10, 13, 'h' # Esc or ? or q or Enter or h
          @mode = @previous_mode || :list
          recalculate_layout
        end
      end

      def handle_filter_input(key)
        case key
        when 27, 'q' # Esc or q
          if @filter_window.back
            apply_filters
            @mode = @previous_mode || :list
            recalculate_layout
          end
        when 'j', Curses::KEY_DOWN
          @filter_window.move_down
        when 'k', Curses::KEY_UP
          @filter_window.move_up
        when Curses::KEY_ENTER, 10, 13
          @filter_window.select
        when 'c'
          @list_window.clear_filters
          @filter_window.set_filters({})
          @last_refresh = Time.now
          # Close filter menu and return to previous view
          @mode = @previous_mode || :list
          recalculate_layout
        when 'f' # Toggle filter menu off
          apply_filters
          @mode = @previous_mode || :list
          recalculate_layout
        end
      end

      def handle_search_input(key)
        case key
        when 27 # Esc
          exit_search_mode(apply: false)
        when Curses::KEY_ENTER, 10, 13
          exit_search_mode(apply: true)
        when Curses::KEY_BACKSPACE, 127, 8
          @search_buffer = @search_buffer[0..-2]
        when String
          @search_buffer += key if key.length == 1 && key.ord >= 32
        when Integer
          @search_buffer += key.chr if key >= 32 && key < 127
        end
      end

      def handle_agents_input(key)
        case key
        when 'q', 27 # q or Esc
          exit_agents_mode
        when 'j', Curses::KEY_DOWN
          @agents_window.move_down
        when 'k', Curses::KEY_UP
          @agents_window.move_up
        when 'g', Curses::KEY_HOME
          @agents_window.go_to_top
        when 'G', Curses::KEY_END
          @agents_window.go_to_bottom
        when Curses::KEY_ENTER, 10, 13
          view_agent_request
        when 'l'
          view_agent_output
        when 'd'
          delete_selected_agent
        when 'o'
          open_agent_worktree
        when 'r'
          @agents_window.load_agents
        when '?'
          @previous_mode = :agents
          @mode = :help
          recalculate_layout
        end
      end

      def handle_agent_output_input(key)
        case key
        when 'q', 27 # q or Esc
          exit_agent_output_mode
        when 'j', Curses::KEY_DOWN
          @agent_output_window.scroll_down
        when 'k', Curses::KEY_UP
          @agent_output_window.scroll_up
        when Curses::KEY_NPAGE, 4, 14 # Ctrl+D, Ctrl+N
          @agent_output_window.page_down
        when Curses::KEY_PPAGE, 21, 16 # Ctrl+U, Ctrl+P
          @agent_output_window.page_up
        when 'g', Curses::KEY_HOME
          @agent_output_window.go_to_top
        when 'G', Curses::KEY_END
          @agent_output_window.go_to_bottom
        when 'r'
          @agent_output_window.load_output
        end
      end

      def enter_detail_mode
        return unless @list_window.selected_request

        @mode = :detail
        recalculate_layout
        @list_window.load_requests
        @detail_window.set_request(@list_window.selected_request)
      end

      def exit_detail_mode
        @mode = :list
        @detail_window = nil
        recalculate_layout
        @list_window.load_requests
      end

      def update_detail_request
        @detail_window.set_request(@list_window.selected_request, reset_tab: false) if @list_window.selected_request
      end

      def enter_search_mode
        @mode = :search
        @search_buffer = @list_window.search_query || ''
      end

      def exit_search_mode(apply:)
        Curses.curs_set(0) # Hide cursor
        if apply
          @list_window.set_search(@search_buffer)
          @last_refresh = Time.now
        end
        @mode = :list
        @search_buffer = ''
      end

      def enter_filter_mode
        @mode = :filter
        recalculate_layout
      end

      def apply_filters
        @filter_window.selected_filters.each do |key, value|
          @list_window.set_filter(key, value)
        end
        @last_refresh = Time.now
      end

      def delete_selected_request
        request = @list_window.selected_request
        return unless request

        request.destroy
        load_data
      end

      def delete_all_requests
        # Show confirmation? For now, just delete all matching current filters
        Binocs::Request.delete_all
        load_data
      end

      def open_swagger_in_browser
        return unless @detail_window&.swagger_operation

        url = Binocs::Swagger::PathMatcher.build_swagger_ui_url(@detail_window.swagger_operation)
        return unless url

        # Open URL in default browser
        if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
          system("start", url)
        elsif RbConfig::CONFIG['host_os'] =~ /darwin/
          system("open", url)
        else
          system("xdg-open", url)
        end
      end

      # Agent mode methods
      def enter_agents_mode
        @previous_mode = @mode
        @mode = :agents
        recalculate_layout
      end

      def exit_agents_mode
        @mode = @previous_mode || :list
        @previous_mode = nil
        recalculate_layout
      end

      def view_agent_request
        agent = @agents_window&.selected_agent
        return unless agent

        # Find the request in the list and select it
        request = Binocs::Request.find_by(id: agent.request_id)
        return unless request

        # Find the index of this request in the current list
        @list_window.load_requests
        request_index = @list_window.requests.find_index { |r| r.id == request.id }

        if request_index
          @list_window.selected_index = request_index

          # Enter detail mode and go to Agent tab with input active
          @mode = :detail
          recalculate_layout
          @list_window.load_requests
          @detail_window.set_request(request)
          @detail_window.go_to_tab(8) # Agent tab
          @detail_window.agent_input_active = true
          Curses.curs_set(1)
        end
      end

      def view_agent_output
        agent = @agents_window&.selected_agent
        return unless agent

        @previous_mode = :agents
        @mode = :agent_output
        recalculate_layout
        @agent_output_window.set_agent(agent)
      end

      def exit_agent_output_mode
        @mode = :agents
        recalculate_layout
      end

      def delete_selected_agent
        agent = @agents_window&.selected_agent
        return unless agent

        Binocs::AgentManager.cleanup(agent)
        @agents_window.load_agents
      end

      def open_agent_worktree
        agent = @agents_window&.selected_agent
        return unless agent

        Binocs::AgentManager.open_worktree(agent)
      end

      def restore_list_state(state)
        return unless state && @list_window

        @list_window.selected_index = state[:selected_index]
        @list_window.scroll_offset = state[:scroll_offset]
        @list_window.instance_variable_set(:@filters, state[:filters])
        @list_window.instance_variable_set(:@search_query, state[:search_query])
      end

      def cleanup
        Curses.close_screen
      end
    end
  end
end
