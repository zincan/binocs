# frozen_string_literal: true

require 'securerandom'
require 'shellwords'

module Binocs
  class Agent
    STATUSES = %i[pending running completed failed stopped].freeze
    TOOLS = %i[claude_code opencode].freeze

    attr_accessor :id, :status, :tool, :worktree_path, :pid, :request_id,
                  :prompt, :created_at, :output_file, :branch_name,
                  :request_context, :exit_code

    @@agents = []
    @@mutex = Mutex.new

    def initialize(attrs = {})
      @id = attrs[:id] || SecureRandom.uuid[0, 8]
      @status = attrs[:status] || :pending
      @tool = attrs[:tool] || Binocs.configuration.agent_tool
      @worktree_path = attrs[:worktree_path]
      @pid = attrs[:pid]
      @request_id = attrs[:request_id]
      @prompt = attrs[:prompt]
      @created_at = attrs[:created_at] || Time.now
      @output_file = attrs[:output_file]
      @branch_name = attrs[:branch_name]
      @request_context = attrs[:request_context]
      @exit_code = nil
    end

    def running?
      @status == :running && @pid && process_alive?
    end

    def completed?
      @status == :completed
    end

    def failed?
      @status == :failed
    end

    def stopped?
      @status == :stopped
    end

    def process_alive?
      return false unless @pid

      Process.kill(0, @pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def stop!
      return unless running?

      begin
        Process.kill('TERM', @pid)
        sleep 0.5
        Process.kill('KILL', @pid) if process_alive?
      rescue Errno::ESRCH, Errno::EPERM
        # Process already dead
      end

      @status = :stopped
    end

    def output
      return '' unless @output_file && File.exist?(@output_file)

      File.read(@output_file)
    end

    def output_tail(lines = 50)
      return '' unless @output_file && File.exist?(@output_file)

      `tail -n #{lines} #{@output_file.shellescape}`.strip
    end

    def duration
      return nil unless @created_at

      elapsed = Time.now - @created_at
      if elapsed < 60
        "#{elapsed.to_i}s"
      elsif elapsed < 3600
        "#{(elapsed / 60).to_i}m"
      else
        "#{(elapsed / 3600).to_i}h #{((elapsed % 3600) / 60).to_i}m"
      end
    end

    def tool_command
      case @tool
      when :claude_code then 'claude'
      when :opencode then 'opencode'
      else 'claude'
      end
    end

    def short_prompt(max_length = 50)
      return '' unless @prompt

      @prompt.length > max_length ? "#{@prompt[0, max_length - 3]}..." : @prompt
    end

    # Class methods for agent registry
    class << self
      def all
        @@mutex.synchronize { @@agents.dup }
      end

      def running
        all.select(&:running?)
      end

      def find(id)
        @@mutex.synchronize { @@agents.find { |a| a.id == id } }
      end

      def add(agent)
        @@mutex.synchronize { @@agents << agent }
        agent
      end

      def remove(agent)
        @@mutex.synchronize { @@agents.delete(agent) }
      end

      def for_request(request_id)
        all.select { |a| a.request_id == request_id }
      end

      def count
        @@mutex.synchronize { @@agents.length }
      end

      def running_count
        running.length
      end

      def clear_completed
        @@mutex.synchronize do
          @@agents.reject! { |a| a.completed? || a.failed? || a.stopped? }
        end
      end
    end
  end
end
