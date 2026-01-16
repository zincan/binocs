# frozen_string_literal: true

module Binocs
  module TUI
    class RequestDetail < Window
      TABS = %w[Overview Params Headers Body Response Logs Exception Swagger].freeze

      attr_accessor :request, :current_tab, :scroll_offset, :swagger_operation

      def initialize(height:, width:, top:, left:)
        super
        @request = nil
        @current_tab = 0
        @scroll_offset = 0
        @content_lines = []
        @swagger_operation = nil
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
        draw_footer
        refresh
      end

      private

      def content_height
        @height - 7 # Box (2) + header (2) + tabs (1) + footer (2)
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

        TABS.each_with_index do |tab, i|
          is_selected = i == @current_tab

          if is_selected
            @win.attron(Curses.color_pair(Colors::SELECTED) | Curses::A_BOLD) do
              @win.setpos(y, x)
              @win.addstr(" #{tab} ")
            end
          else
            @win.attron(Curses.color_pair(Colors::MUTED)) do
              @win.setpos(y, x)
              @win.addstr(" #{tab} ")
            end
          end

          x += tab.length + 3
        end

        # Draw separator
        write(4, 1, '─' * (@width - 2), Colors::BORDER)
      end

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
        end
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

        # Key hints
        hints = "Tab:switch  j/k:scroll  h/Esc:back"
        write(y, @width - hints.length - 2, hints, Colors::KEY_HINT, Curses::A_DIM)
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
