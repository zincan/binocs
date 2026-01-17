# frozen_string_literal: true

module Binocs
  module TUI
    class RequestDetail < Window
      TABS = %w[Overview Params Headers Body Response Logs Exception Swagger Agent].freeze

      attr_accessor :request, :current_tab, :scroll_offset, :swagger_operation,
                    :agent_input, :agent_input_cursor, :agent_input_active,
                    :agent_use_worktree, :agent_tool, :agent_worktree_name,
                    :agent_worktree_name_cursor, :agent_worktree_input_active

      def initialize(height:, width:, top:, left:)
        super
        @request = nil
        @current_tab = 0
        @scroll_offset = 0
        @content_lines = []
        @swagger_operation = nil
        reset_agent_state
      end

      def reset_agent_state
        @agent_input = ''
        @agent_input_cursor = 0
        @agent_input_active = false
        @agent_use_worktree = false
        @agent_worktree_name = ''
        @agent_worktree_name_cursor = 0
        @agent_worktree_input_active = false
        @agent_tool = Binocs.configuration.agent_tool
      end

      def set_request(request, reset_tab: true)
        @request = request
        @current_tab = 0 if reset_tab
        @scroll_offset = 0
        @swagger_operation = Binocs::Swagger::PathMatcher.find_operation(request) if request
        build_content
      end

      def next_tab
        @current_tab = (@current_tab + 1) % TABS.length
        @scroll_offset = 0
        build_content
      end

      def prev_tab
        @current_tab = (@current_tab - 1) % TABS.length
        @scroll_offset = 0
        build_content
      end

      def go_to_tab(index)
        return if index < 0 || index >= TABS.length

        @current_tab = index
        @scroll_offset = 0
        build_content
      end

      def scroll_up
        @scroll_offset = [@scroll_offset - 1, 0].max
      end

      def scroll_down
        max_scroll = [@content_lines.length - content_height, 0].max
        @scroll_offset = [@scroll_offset + 1, max_scroll].min
      end

      def page_up
        @scroll_offset = [@scroll_offset - content_height, 0].max
      end

      def page_down
        max_scroll = [@content_lines.length - content_height, 0].max
        @scroll_offset = [@scroll_offset + content_height, max_scroll].min
      end

      def draw
        return unless @request

        clear
        draw_box("Request Detail")
        draw_header
        draw_tabs
        draw_content
        draw_agent_input if agent_tab?
        draw_footer
        draw_agent_cursor if agent_tab? && @agent_input_active
        refresh
      end

      private

      def content_height
        base = @height - 7 # Box (2) + header (2) + tabs (1) + footer (2)
        # Reserve space for input area in Agent tab
        agent_tab? ? base - 3 : base
      end

      def content_width
        @width - 4
      end

      def draw_header
        y = 1

        # Method and status
        method = @request.method.to_s
        status = @request.status_code.to_s

        @win.setpos(y, 2)
        @win.attron(Curses.color_pair(Colors.method_color(@request.method)) | Curses::A_BOLD) do
          @win.addstr(method)
        end
        @win.addstr(' ')
        @win.attron(Curses.color_pair(Colors.status_color(@request.status_code)) | Curses::A_BOLD) do
          @win.addstr(status)
        end
        @win.addstr(' ')
        @win.attron(Curses.color_pair(Colors::NORMAL)) do
          path = truncate(@request.path, @width - method.length - status.length - 10)
          @win.addstr(path)
        end

        # Second line: duration and time
        y = 2
        info = "#{@request.formatted_duration}  •  #{@request.ip_address || 'N/A'}  •  #{@request.created_at&.strftime('%Y-%m-%d %H:%M:%S')}"
        write(y, 2, info, Colors::MUTED, Curses::A_DIM)
      end

      def draw_tabs
        y = 3
        x = 2

        # Superscript hotkeys: 1-8 for first 8 tabs, 'a' for Agent
        superscripts = %w[¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ᵃ]

        TABS.each_with_index do |tab, i|
          is_selected = i == @current_tab
          hotkey = superscripts[i]

          # Draw tab name
          if is_selected
            @win.attron(Curses.color_pair(Colors::SELECTED) | Curses::A_BOLD) do
              @win.setpos(y, x)
              @win.addstr(tab)
            end
          else
            @win.attron(Curses.color_pair(Colors::MUTED)) do
              @win.setpos(y, x)
              @win.addstr(tab)
            end
          end
          x += tab.length

          # Draw superscript hotkey after tab name
          @win.attron(Curses.color_pair(Colors::MUTED) | Curses::A_DIM) do
            @win.setpos(y, x)
            @win.addstr(hotkey)
          end
          x += 2  # superscript + space
        end

        # Draw separator
        write(4, 1, '─' * (@width - 2), Colors::BORDER)
      end

      public

      # Agent tab methods - need to be public for app.rb to call
      def build_content
        @content_lines = []
        return unless @request

        case TABS[@current_tab]
        when 'Overview' then build_overview
        when 'Params' then build_params
        when 'Headers' then build_headers
        when 'Body' then build_body
        when 'Response' then build_response
        when 'Logs' then build_logs
        when 'Exception' then build_exception
        when 'Swagger' then build_swagger
        when 'Agent' then build_agent
        end
      end

      def agent_tab?
        TABS[@current_tab] == 'Agent'
      end

      def current_agent
        return nil unless @request
        Binocs::Agent.for_request(@request.id).first
      end

      def agent_tool_label
        case @agent_tool
        when :claude_code then 'Claude Code'
        when :opencode then 'OpenCode'
        else @agent_tool.to_s
        end
      end

      def cycle_agent_tool
        tools = [:claude_code, :opencode]
        current_index = tools.find_index(@agent_tool) || 0
        @agent_tool = tools[(current_index + 1) % tools.length]
      end

      def toggle_worktree_mode
        if @agent_use_worktree
          # Turning off worktree mode
          @agent_use_worktree = false
          @agent_worktree_name = ''
          @agent_worktree_input_active = false
        else
          # Turning on worktree mode - prompt for name
          timestamp = Time.now.strftime('%m%d-%H%M')
          @agent_worktree_name = "#{timestamp}-fix"
          @agent_worktree_name_cursor = @agent_worktree_name.length
          @agent_worktree_input_active = true
          @agent_input_active = false
        end
      end

      def confirm_worktree_name
        if @agent_worktree_name.strip.empty?
          # Cancelled - go back to current branch mode
          @agent_use_worktree = false
        else
          @agent_use_worktree = true
        end
        @agent_worktree_input_active = false
      end

      def cancel_worktree_input
        @agent_use_worktree = false
        @agent_worktree_name = ''
        @agent_worktree_input_active = false
      end

      def handle_agent_key(key)
        return false unless agent_tab?

        # If worktree name input is active
        if @agent_worktree_input_active
          case key
          when 27 # Esc - cancel
            cancel_worktree_input
            return true
          when Curses::KEY_ENTER, 10, 13
            confirm_worktree_name
            return true
          when Curses::KEY_BACKSPACE, 127, 8
            if @agent_worktree_name_cursor > 0
              @agent_worktree_name = @agent_worktree_name[0, @agent_worktree_name_cursor - 1] + @agent_worktree_name[@agent_worktree_name_cursor..]
              @agent_worktree_name_cursor -= 1
            end
            return true
          when Curses::KEY_LEFT
            @agent_worktree_name_cursor = [@agent_worktree_name_cursor - 1, 0].max
            return true
          when Curses::KEY_RIGHT
            @agent_worktree_name_cursor = [@agent_worktree_name_cursor + 1, @agent_worktree_name.length].min
            return true
          when String
            # Only allow valid branch name characters
            if key.length == 1 && key =~ /[a-zA-Z0-9\-_]/
              @agent_worktree_name = @agent_worktree_name[0, @agent_worktree_name_cursor] + key + (@agent_worktree_name[@agent_worktree_name_cursor..] || '')
              @agent_worktree_name_cursor += 1
            end
            return true
          when Integer
            if key >= 32 && key < 127
              char = key.chr
              if char =~ /[a-zA-Z0-9\-_]/
                @agent_worktree_name = @agent_worktree_name[0, @agent_worktree_name_cursor] + char + (@agent_worktree_name[@agent_worktree_name_cursor..] || '')
                @agent_worktree_name_cursor += 1
              end
            end
            return true
          end
          return true
        end

        # If input is active, handle text input first
        if @agent_input_active
          case key
          when 27 # Esc - cancel input
            @agent_input_active = false
            return true
          when Curses::KEY_ENTER, 10, 13
            # Enter submits if we have input
            if @agent_input.strip.length > 0
              submit_agent_prompt
            end
            return true
          when Curses::KEY_BACKSPACE, 127, 8
            if @agent_input_cursor > 0
              @agent_input = @agent_input[0, @agent_input_cursor - 1] + @agent_input[@agent_input_cursor..]
              @agent_input_cursor -= 1
            end
            return true
          when Curses::KEY_LEFT
            @agent_input_cursor = [@agent_input_cursor - 1, 0].max
            return true
          when Curses::KEY_RIGHT
            @agent_input_cursor = [@agent_input_cursor + 1, @agent_input.length].min
            return true
          when Curses::KEY_HOME
            @agent_input_cursor = 0
            return true
          when Curses::KEY_END
            @agent_input_cursor = @agent_input.length
            return true
          when String
            if key.length == 1 && key.ord >= 32
              @agent_input = @agent_input[0, @agent_input_cursor] + key + (@agent_input[@agent_input_cursor..] || '')
              @agent_input_cursor += 1
            end
            return true
          when Integer
            if key >= 32 && key < 127
              char = key.chr
              @agent_input = @agent_input[0, @agent_input_cursor] + char + (@agent_input[@agent_input_cursor..] || '')
              @agent_input_cursor += 1
            end
            return true
          end
          return true # Consume all keys when input is active
        end

        # Not in input mode - handle commands
        case key
        when 'i', Curses::KEY_ENTER, 10, 13
          @agent_input_active = true
          return true
        when 't', 'T'
          cycle_agent_tool
          return true
        when 'w', 'W'
          toggle_worktree_mode
          return true
        when 's', 'S'
          stop_current_agent
          return true
        end

        false
      end

      def submit_agent_prompt
        return if @agent_input.strip.empty?
        return unless @request

        prompt = @agent_input.strip
        @agent_input = ''
        @agent_input_cursor = 0
        @agent_input_active = false

        # Check if there's an existing agent for this request
        existing_agent = current_agent

        if existing_agent && !existing_agent.running?
          # Continue in same directory with new prompt
          Binocs::AgentManager.continue_session(
            agent: existing_agent,
            prompt: prompt,
            tool: @agent_tool
          )
        else
          # Launch new agent
          Binocs::AgentManager.launch(
            request: @request,
            prompt: prompt,
            tool: @agent_tool,
            use_worktree: @agent_use_worktree,
            branch_name: @agent_use_worktree ? @agent_worktree_name : nil
          )
        end

        build_content
      end

      def stop_current_agent
        agent = current_agent
        return unless agent&.running?

        agent.stop!
        build_content
      end

      def build_overview
        add_section('Request Information')
        add_field('Method', @request.method)
        add_field('Path', @request.path)
        add_field('Full URL', @request.full_url)
        add_field('Controller', @request.controller_name || 'N/A')
        add_field('Action', @request.action_name || 'N/A')
        add_blank

        add_section('Response')
        add_field('Status', @request.status_code.to_s)
        add_field('Duration', @request.formatted_duration)
        add_field('Memory Delta', @request.formatted_memory_delta)
        add_blank

        add_section('Client')
        add_field('IP Address', @request.ip_address || 'N/A')
        add_field('Session ID', @request.session_id || 'N/A')
        add_blank

        add_section('Timing')
        add_field('Created At', @request.created_at&.strftime('%Y-%m-%d %H:%M:%S.%L'))

        if @request.has_exception?
          add_blank
          add_line('!! HAS EXCEPTION - See Exception tab', Colors::ERROR)
        end
      end

      def build_params
        params = @request.params
        if params.present? && params.any?
          add_section('Request Parameters')
          format_hash(params)
        else
          add_line('No parameters', Colors::MUTED)
        end
      end

      def build_headers
        add_section('Request Headers')
        req_headers = @request.request_headers
        if req_headers.present? && req_headers.any?
          format_hash(req_headers)
        else
          add_line('No request headers', Colors::MUTED)
        end

        add_blank
        add_section('Response Headers')
        res_headers = @request.response_headers
        if res_headers.present? && res_headers.any?
          format_hash(res_headers)
        else
          add_line('No response headers', Colors::MUTED)
        end
      end

      def build_body
        body = @request.request_body
        if body.present?
          add_section('Request Body')
          format_body(body)
        else
          add_line('No request body', Colors::MUTED)
        end
      end

      def build_response
        body = @request.response_body
        if body.present?
          add_section('Response Body')
          format_body(body)
        else
          add_line('No response body captured', Colors::MUTED)
        end
      end

      def build_logs
        logs = @request.logs
        if logs.present? && logs.any?
          logs.each_with_index do |log, i|
            add_section("Log Entry #{i + 1} - #{log['type']&.upcase}")
            add_field('Timestamp', log['timestamp'])

            case log['type']
            when 'controller'
              add_field('Controller', "#{log['controller']}##{log['action']}")
              add_field('Format', log['format'])
              add_field('View Runtime', "#{log['view_runtime']}ms") if log['view_runtime']
              add_field('DB Runtime', "#{log['db_runtime']}ms") if log['db_runtime']
              add_field('Duration', "#{log['duration']}ms")
            when 'redirect'
              add_field('Location', log['location'])
              add_field('Status', log['status'])
            else
              log.each do |key, value|
                next if key == 'timestamp' || key == 'type'
                add_field(key.to_s.titleize, value.to_s)
              end
            end
            add_blank
          end
        else
          add_line('No logs captured', Colors::MUTED)
        end
      end

      def build_exception
        exc = @request.exception
        if exc.present?
          add_section('Exception Details')
          add_field('Class', exc['class'], Colors::ERROR)
          add_blank
          add_field('Message', exc['message'], Colors::ERROR)
          add_blank

          if exc['backtrace'].present?
            add_section('Backtrace')
            exc['backtrace'].each do |line|
              add_line(line, Colors::MUTED)
            end
          end
        else
          add_line('No exception', Colors::STATUS_SUCCESS)
        end
      end

      def build_swagger
        unless @swagger_operation
          add_line('No matching Swagger operation found', Colors::MUTED)
          add_blank
          add_line("Request: #{@request.method} #{@request.path}", Colors::MUTED)
          add_blank
          add_line('Ensure swagger_spec_url is configured correctly.', Colors::MUTED)
          return
        end

        op = @swagger_operation

        add_section('Operation')
        add_field('Operation ID', op[:operation_id] || 'N/A')
        add_field('Spec Path', op[:spec_path])
        add_field('Method', op[:method].upcase)
        add_field('Tags', op[:tags].join(', ')) if op[:tags].any?
        add_field('Deprecated', 'Yes', Colors::ERROR) if op[:deprecated]
        add_blank

        if op[:summary].present?
          add_section('Summary')
          add_line(op[:summary], Colors::NORMAL)
          add_blank
        end

        if op[:description].present?
          add_section('Description')
          op[:description].each_line do |line|
            add_line(line.chomp, Colors::NORMAL)
          end
          add_blank
        end

        if op[:parameters].any?
          add_section('Parameters')
          op[:parameters].each do |param|
            location = param['in']
            name = param['name']
            required = param['required'] ? '*' : ''
            param_type = param.dig('schema', 'type') || 'any'
            add_field("#{location}:#{name}#{required}", param_type)
            if param['description'].present?
              add_line("  #{param['description']}", Colors::MUTED)
            end
          end
          add_blank
        end

        if op[:request_body].present?
          add_section('Request Body')
          content = op[:request_body]['content']
          if content
            content.each do |media_type, schema_info|
              add_field('Content-Type', media_type)
              if schema_info['schema']
                format_schema(schema_info['schema'], 1)
              end
            end
          end
          add_blank
        end

        if op[:responses].any?
          add_section('Responses')
          op[:responses].each do |status, response_info|
            description = response_info['description'] || ''
            color = status.to_s.start_with?('2') ? Colors::STATUS_SUCCESS :
                    status.to_s.start_with?('4') ? Colors::STATUS_CLIENT_ERROR :
                    status.to_s.start_with?('5') ? Colors::STATUS_SERVER_ERROR : Colors::NORMAL
            add_field(status.to_s, description, color)
          end
          add_blank
        end

        add_line("Press 'o' to open in browser", Colors::KEY_HINT)
      end

      def build_agent
        agent = current_agent
        agents_for_request = Binocs::Agent.for_request(@request.id)

        # Settings section
        add_section('Settings')
        add_field('Tool', agent_tool_label)
        if @agent_use_worktree && @agent_worktree_name.present?
          add_field('Mode', "Worktree: agent/#{@agent_worktree_name}")
        else
          add_field('Mode', 'Current Branch')
        end
        add_blank
        add_line("Press 't' to change tool, 'w' to #{@agent_use_worktree ? 'disable' : 'enable'} worktree mode", Colors::KEY_HINT)
        add_blank

        if agent
          # Status section
          add_section('Agent Status')
          status_color = case agent.status
                         when :running then Colors::STATUS_SUCCESS
                         when :completed then Colors::HEADER
                         when :failed, :stopped then Colors::ERROR
                         else Colors::MUTED
                         end
          add_field('Status', agent.status.to_s.upcase, status_color)
          add_field('Tool', agent.tool_command)
          add_field('Duration', agent.duration)
          add_field('Branch', agent.branch_name) if agent.branch_name
          add_field('Worktree', agent.worktree_path) if agent.worktree_path
          add_blank

          if agent.running?
            add_line("Press 's' to stop the agent", Colors::KEY_HINT)
            add_blank
          end

          # Show agent prompt
          if agent.prompt.present?
            add_section('Prompt')
            agent.prompt.each_line do |line|
              add_line(line.chomp, Colors::NORMAL)
            end
            add_blank
          end

          # Show recent output
          add_section('Output (last 30 lines)')
          output = agent.output_tail(30)
          if output.present?
            output.each_line do |line|
              add_line(line.chomp, Colors::MUTED)
            end
          else
            add_line('No output yet...', Colors::MUTED)
          end
        else
          # No agent yet - show context preview
          add_section('Context (will be sent to agent)')
          method_str = @request.respond_to?(:read_attribute) ? @request.read_attribute(:method) : @request.method
          add_line("#{method_str} #{@request.path} -> #{@request.status_code}", Colors::NORMAL)
          if @request.controller_name
            add_line("#{@request.controller_name}##{@request.action_name}", Colors::MUTED)
          end
          if @request.has_exception?
            add_line("Exception: #{@request.exception&.dig('class')}", Colors::ERROR)
          end
          add_blank
          add_line("Press 'i' or Enter to compose a prompt for the AI agent", Colors::KEY_HINT)
        end

        # Show history of agents if more than current
        if agents_for_request.length > 1
          add_blank
          add_section("Agent History (#{agents_for_request.length} total)")
          agents_for_request.each do |a|
            status_indicator = case a.status
                               when :running then '●'
                               when :completed then '✓'
                               when :failed then '✗'
                               else '○'
                               end
            add_line("#{status_indicator} #{a.short_prompt(40)} (#{a.duration})", Colors::MUTED)
          end
        end
      end

      def content_as_text
        # Convert content_lines to plain text for copying
        lines = []
        @content_lines.each do |line|
          case line[:type]
          when :section
            lines << ""
            lines << "── #{line[:text]} ──"
          when :field
            lines << "#{line[:label]}: #{line[:value]}"
          when :line
            lines << line[:text]
          when :blank
            lines << ""
          end
        end
        lines.join("\n")
      end

      def copy_to_clipboard(text)
        # Try different clipboard commands based on platform
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          IO.popen('pbcopy', 'w') { |io| io.write(text) }
          true
        elsif system('which xclip > /dev/null 2>&1')
          IO.popen('xclip -selection clipboard', 'w') { |io| io.write(text) }
          true
        elsif system('which xsel > /dev/null 2>&1')
          IO.popen('xsel --clipboard --input', 'w') { |io| io.write(text) }
          true
        else
          false
        end
      rescue
        false
      end

      private

      # Helper methods for content building
      def format_schema(schema, indent = 0)
        prefix = '  ' * indent
        if schema['type'] == 'object' && schema['properties']
          schema['properties'].each do |prop_name, prop_schema|
            prop_type = prop_schema['type'] || 'any'
            required_mark = schema['required']&.include?(prop_name) ? '*' : ''
            add_line("#{prefix}#{prop_name}#{required_mark}: #{prop_type}", Colors::NORMAL)
          end
        elsif schema['type'] == 'array' && schema['items']
          add_line("#{prefix}array of:", Colors::NORMAL)
          format_schema(schema['items'], indent + 1)
        elsif schema['$ref']
          ref_name = schema['$ref'].split('/').last
          add_line("#{prefix}$ref: #{ref_name}", Colors::MUTED)
        else
          add_line("#{prefix}type: #{schema['type'] || 'any'}", Colors::NORMAL)
        end
      end

      def add_section(title)
        @content_lines << { type: :section, text: title }
      end

      def add_field(label, value, color = nil)
        @content_lines << { type: :field, label: label, value: value.to_s, color: color }
      end

      def add_line(text, color = Colors::NORMAL)
        @content_lines << { type: :line, text: text, color: color }
      end

      def add_blank
        @content_lines << { type: :blank }
      end

      def format_hash(hash, indent = 0)
        hash.each do |key, value|
          if value.is_a?(Hash)
            add_line("  " * indent + "#{key}:", Colors::HEADER)
            format_hash(value, indent + 1)
          elsif value.is_a?(Array)
            add_line("  " * indent + "#{key}: [#{value.length} items]", Colors::HEADER)
            value.each_with_index do |item, i|
              if item.is_a?(Hash)
                add_line("  " * (indent + 1) + "[#{i}]:", Colors::MUTED)
                format_hash(item, indent + 2)
              else
                add_line("  " * (indent + 1) + "- #{item}", Colors::NORMAL)
              end
            end
          else
            add_field("  " * indent + key.to_s, value.to_s)
          end
        end
      end

      def format_body(body)
        begin
          parsed = JSON.parse(body)
          formatted = JSON.pretty_generate(parsed)
          formatted.each_line do |line|
            add_line(line.chomp, Colors::NORMAL)
          end
        rescue JSON::ParserError
          body.each_line do |line|
            add_line(line.chomp, Colors::NORMAL)
          end
        end
      end

      def draw_content
        start_y = 5
        visible = content_height

        visible.times do |i|
          line_index = @scroll_offset + i
          break if line_index >= @content_lines.length

          line = @content_lines[line_index]
          y = start_y + i

          case line[:type]
          when :section
            write(y, 2, "── #{line[:text]} ", Colors::HEADER, Curses::A_BOLD)
          when :field
            label = "#{line[:label]}: "
            write(y, 2, label, Colors::MUTED, Curses::A_DIM)
            color = line[:color] || Colors::NORMAL
            write(y, 2 + label.length, truncate(line[:value], content_width - label.length), color)
          when :line
            write(y, 2, truncate(line[:text], content_width), line[:color] || Colors::NORMAL)
          when :blank
            # Nothing to draw
          end
        end
      end

      def draw_footer
        y = @height - 2
        write(y - 1, 1, '─' * (@width - 2), Colors::BORDER)

        # Scroll indicator
        if @content_lines.length > content_height
          scroll_info = "Line #{@scroll_offset + 1}-#{[@scroll_offset + content_height, @content_lines.length].min} of #{@content_lines.length}"
          write(y, 2, scroll_info, Colors::MUTED, Curses::A_DIM)
        end

        # Key hints - context sensitive for Agent tab
        if agent_tab?
          hints = @agent_input_active ? "Enter:send  Esc:cancel" : "i:input  t:tool  w:worktree  s:stop"
        else
          hints = "Tab:switch  j/k:scroll  h/Esc:back"
        end
        write(y, @width - hints.length - 2, hints, Colors::KEY_HINT, Curses::A_DIM)
      end

      def draw_agent_input
        # Draw input area above footer
        input_y = @height - 5
        write(input_y, 1, '─' * (@width - 2), Colors::BORDER)

        label_y = input_y + 1
        if @agent_worktree_input_active
          # Worktree name input mode
          write(label_y, 2, "Worktree name: agent/", Colors::HEADER, Curses::A_BOLD)
          write(label_y, 23, @agent_worktree_name, Colors::NORMAL)
          # Show explanation on next line
          write(label_y + 1, 2, "All changes will be isolated in this worktree. Enter to confirm, Esc to cancel.", Colors::MUTED, Curses::A_DIM)
        elsif @agent_input_active
          write(label_y, 2, "Prompt: ", Colors::HEADER, Curses::A_BOLD)
          # Draw input text
          display_input = @agent_input.length > content_width - 10 ?
            @agent_input[-content_width + 10..] : @agent_input
          write(label_y, 10, display_input, Colors::NORMAL)
        else
          agent = current_agent
          if agent&.running?
            write(label_y, 2, "Agent is running... Press 's' to stop", Colors::STATUS_SUCCESS)
          else
            write(label_y, 2, "Press 'i' or Enter to start composing a prompt", Colors::MUTED)
          end
        end
      end

      def draw_agent_cursor
        if @agent_worktree_input_active
          Curses.curs_set(1)
          cursor_y = @height - 4
          cursor_x = 23 + @agent_worktree_name_cursor
          @win.setpos(cursor_y, [cursor_x, content_width].min)
        elsif @agent_input_active
          Curses.curs_set(1)
          cursor_y = @height - 4
          # Calculate cursor x position accounting for scrolling
          visible_start = [@agent_input.length - (content_width - 10), 0].max
          cursor_x = 10 + (@agent_input_cursor - visible_start)
          cursor_x = [cursor_x, content_width].min
          @win.setpos(cursor_y, cursor_x)
        end
      end

      def truncate(str, max_length)
        str = str.to_s
        return str if str.length <= max_length
        return str if max_length < 4

        "#{str[0, max_length - 3]}..."
      end
    end
  end
end
