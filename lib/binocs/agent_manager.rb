# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'open3'

module Binocs
  class AgentManager
    class << self
      def launch(request:, prompt:, tool: nil, branch_name: nil, use_worktree: false)
        tool ||= Binocs.configuration.agent_tool

        # Create agent record
        agent = Agent.new(
          request_id: request.id,
          prompt: prompt,
          tool: tool,
          request_context: AgentContext.build(request)
        )

        # Set up output file path early so we can log to it
        base_dir = worktree_base_path
        FileUtils.mkdir_p(base_dir)

        # Generate a name for logs
        timestamp = Time.now.strftime('%m%d-%H%M%S')
        prompt_slug = generate_slug(agent.prompt)
        log_name = "#{timestamp}-#{prompt_slug}"
        agent.output_file = File.join(base_dir, "#{log_name}.log")

        # Start logging
        log_to_agent(agent, "=" * 60)
        log_to_agent(agent, "Binocs Agent Started")
        log_to_agent(agent, "Time: #{Time.now}")
        log_to_agent(agent, "Tool: #{agent.tool}")
        log_to_agent(agent, "Mode: #{use_worktree ? 'New Worktree' : 'Current Branch'}")
        log_to_agent(agent, "=" * 60)
        log_to_agent(agent, "")

        if use_worktree
          # Create worktree for isolated work
          worktree_name = branch_name && !branch_name.empty? ? branch_name : log_name
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Creating git worktree...")
          worktree_path, branch_name = create_worktree(agent, worktree_name)
          agent.worktree_path = worktree_path
          agent.branch_name = branch_name
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Worktree created: #{worktree_path}")
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Branch: #{branch_name}")
          log_to_agent(agent, "")

          # Write context file for the agent
          context_file = File.join(worktree_path, '.binocs-context.md')
          File.write(context_file, agent.request_context)
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Context file written: .binocs-context.md")
        else
          # Run in current directory on current branch
          agent.worktree_path = find_git_root
          agent.branch_name = current_branch_name
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Running on current branch: #{agent.branch_name}")
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Directory: #{agent.worktree_path}")
          log_to_agent(agent, "")

          # Write context file in current directory
          context_file = File.join(agent.worktree_path, '.binocs-context.md')
          File.write(context_file, agent.request_context)
          log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Context file written: .binocs-context.md")
        end

        # Register agent
        Agent.add(agent)

        # Spawn the process
        log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Starting #{agent.tool_command}...")
        log_to_agent(agent, "")
        log_to_agent(agent, "-" * 60)
        log_to_agent(agent, "Agent Output:")
        log_to_agent(agent, "-" * 60)
        log_to_agent(agent, "")
        spawn_agent(agent)

        agent
      end

      def continue_session(agent:, prompt:, tool: nil)
        tool ||= agent.tool

        # Update agent for new session
        agent.prompt = prompt
        agent.tool = tool
        agent.status = :pending
        agent.created_at = Time.now

        # Log continuation
        log_to_agent(agent, "")
        log_to_agent(agent, "=" * 60)
        log_to_agent(agent, "Continuing Session")
        log_to_agent(agent, "Time: #{Time.now}")
        log_to_agent(agent, "Tool: #{tool}")
        log_to_agent(agent, "=" * 60)
        log_to_agent(agent, "")

        log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Continuing in: #{agent.worktree_path}")
        log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] New prompt: #{prompt[0, 50]}...")
        log_to_agent(agent, "")

        # Spawn the process in the same directory
        log_to_agent(agent, "[#{Time.now.strftime('%H:%M:%S')}] Starting #{agent.tool_command}...")
        log_to_agent(agent, "")
        log_to_agent(agent, "-" * 60)
        log_to_agent(agent, "Agent Output:")
        log_to_agent(agent, "-" * 60)
        log_to_agent(agent, "")
        spawn_agent(agent)

        agent
      end

      def log_to_agent(agent, message)
        return unless agent.output_file
        File.open(agent.output_file, 'a') { |f| f.puts(message) }
      end

      def create_worktree(agent, worktree_name)
        base_dir = worktree_base_path
        worktree_path = File.join(base_dir, worktree_name)
        branch_name = "agent/#{worktree_name}"

        # Get current repo root
        repo_root = find_git_root

        # Create the worktree with a new branch, capturing output
        Dir.chdir(repo_root) do
          output = `git worktree add -b #{branch_name.shellescape} #{worktree_path.shellescape} HEAD 2>&1`
          unless $?.success?
            log_to_agent(agent, "[ERROR] Git worktree creation failed:")
            log_to_agent(agent, output)
            raise "Failed to create git worktree at #{worktree_path}: #{output}"
          end
          log_to_agent(agent, output) unless output.strip.empty?
        end

        [worktree_path, branch_name]
      end

      def generate_slug(prompt)
        return 'task' if prompt.nil? || prompt.empty?

        # Take first few words, remove special chars, join with dashes
        words = prompt.downcase.gsub(/[^a-z0-9\s]/, '').split.first(4)
        slug = words.join('-')
        slug = slug[0, 25] if slug.length > 25
        slug.empty? ? 'task' : slug
      end

      def spawn_agent(agent)
        return unless agent.worktree_path && Dir.exist?(agent.worktree_path)

        # Build the full prompt including context
        full_prompt = build_full_prompt(agent)

        # Create a prompt file for the agent to read
        prompt_file = File.join(agent.worktree_path, '.binocs-prompt.md')
        File.write(prompt_file, full_prompt)

        # Build command arguments based on tool
        cmd_args = build_agent_command_args(agent, prompt_file)

        # Spawn the process
        pid = Process.spawn(
          *cmd_args,
          chdir: agent.worktree_path,
          out: [agent.output_file, 'a'],
          err: [agent.output_file, 'a'],
          pgroup: true
        )

        Process.detach(pid)

        agent.pid = pid
        agent.status = :running

        # Start a monitor thread
        start_monitor_thread(agent)
      end

      def cleanup(agent)
        # Stop the process if running
        agent.stop! if agent.running?

        # Remove the worktree
        if agent.worktree_path && Dir.exist?(agent.worktree_path)
          repo_root = find_git_root

          Dir.chdir(repo_root) do
            system("git worktree remove #{agent.worktree_path.shellescape} --force",
                   out: File::NULL, err: File::NULL)
          end

          # Also delete the branch if it exists
          if agent.branch_name
            Dir.chdir(repo_root) do
              system("git branch -D #{agent.branch_name.shellescape}",
                     out: File::NULL, err: File::NULL)
            end
          end
        end

        # Remove from registry
        Agent.remove(agent)
      end

      def open_worktree(agent)
        return unless agent.worktree_path && Dir.exist?(agent.worktree_path)

        # Open in file manager
        if RbConfig::CONFIG['host_os'] =~ /darwin/
          system("open", agent.worktree_path)
        elsif RbConfig::CONFIG['host_os'] =~ /linux/
          system("xdg-open", agent.worktree_path)
        end
      end

      private

      def worktree_base_path
        base = Binocs.configuration.agent_worktree_base
        if base.start_with?('/')
          base
        else
          File.expand_path(base, find_git_root)
        end
      end

      def find_git_root
        dir = Dir.pwd
        while dir != '/'
          return dir if File.exist?(File.join(dir, '.git'))

          dir = File.dirname(dir)
        end
        Dir.pwd
      end

      def current_branch_name
        Dir.chdir(find_git_root) do
          `git rev-parse --abbrev-ref HEAD`.strip
        end
      rescue
        'unknown'
      end

      def build_full_prompt(agent)
        <<~PROMPT
          # Request Context

          The following is context from an HTTP request that was captured by Binocs.
          Use this information to understand the issue and implement a fix.

          #{agent.request_context}

          ---

          # Task

          #{agent.prompt}

          ---

          Note: The request context is also saved in `.binocs-context.md` for reference.
        PROMPT
      end

      def build_agent_command_args(agent, prompt_file)
        prompt_content = File.read(prompt_file)

        case agent.tool
        when :claude_code
          # Claude Code: use -p for prompt, --dangerously-skip-permissions for autonomous mode
          [agent.tool_command, '-p', prompt_content, '--dangerously-skip-permissions']
        when :opencode
          # OpenCode - run with prompt flag
          [agent.tool_command, '-p', prompt_content]
        else
          [agent.tool_command, '-p', prompt_content]
        end
      end

      def start_monitor_thread(agent)
        Thread.new do
          begin
            Process.wait(agent.pid)
            agent.exit_code = $?.exitstatus
            agent.status = agent.exit_code == 0 ? :completed : :failed
          rescue Errno::ECHILD
            # Process already reaped
            agent.status = :completed unless agent.status == :stopped
          end
        end
      end
    end
  end
end
