module Rake
  class Task
    alias old_execute execute
    def execute(args=nil)
      previous_task_name = Thread::current[:task_name]
      Thread::current[:task_name] = name

      result = old_execute(args)

      Thread::current[:task_name] = previous_task_name
      result
    end
  end
end

# Add a backslash in front of each backslash, double quote, backtick, and
# dollar sign in the given string. These are the characters that must be
# escaped in a double-quoted string in a bash script.
def escape_for_double_quotes(str)
  str.gsub(/[\\"`$]/) { |c| "\\#{c}" }
end

module FileUtils
  alias old_sh sh
  def sh(*cmd, &block)
    options = Hash === cmd.last ? cmd.pop : {}
    old_cmd = cmd.clone

    options[:verbose] = false # we output the command ourselves
    cmd << options

    top_level_tasks = Rake.application.top_level_tasks.map { |task| Rake::Task[task] }
    tasks_to_run = top_level_tasks + top_level_tasks.map(&:all_prerequisite_tasks).flatten
    max_task_name_length = tasks_to_run.map { |task| task.name.length }.max

    task_name = Thread::current[:task_name]
    task_name_in_brackets = "[#{task_name}]#{' ' * [1, (max_task_name_length + 1) - task_name.length].max}"

    Rake.rake_output_message "\e[33m#{task_name_in_brackets}#{sh_show_command old_cmd}\e[0m"

    # We use stdbuf -oL -eL to buffer the stdout and stderr of the command by
    # line, rather than having stdout block-buffered (because it's being piped
    # to sed) and stderr unbuffered. This fixes an issue where one line could
    # contain output from multiple Rake tasks that were printing concurrently.
    # old_cmd could be a shell builtin, which stdbuf cannot handle, so we wrap
    # it in bash -c.
    command_with_stdbuf = "stdbuf -oL -eL bash -c \"#{escape_for_double_quotes(old_cmd.first)}\""

    # Add task_name_in_brackets to the start of each line.
    sed_command = "sed \"s/^/#{task_name_in_brackets}/\""

    # We use stdbuf to make sure that the command's output continues to be
    # buffered by line, even after piping it through sed.
    full_command = "( #{command_with_stdbuf} ) > >( stdbuf -oL #{sed_command} ) 2> >( ( stdbuf -oL #{sed_command} ) >&2 )"

    # The command is wrapped in `bash -c` because old_sh calls system, which
    # invokes the command using the sh shell. sh doesn't support process
    # substitution (e.g. `echo hello > >(tr h H)` prints "Hello" in bash but
    # is a syntax error in sh).
    cmd[0] = "bash -c \"#{escape_for_double_quotes(full_command)}\""

    old_sh(*cmd, &block || create_shell_runner(old_cmd))
  end
end
