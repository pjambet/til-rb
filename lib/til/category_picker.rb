require 'readline'

module Til
  # Drives category selection: it checks that fzf is installed, presents the
  # known categories through it, and lets the user fall through to typing a
  # brand-new category name.
  class CategoryPicker

    NEW_CATEGORY_LABEL = 'Something else?'

    def initialize(kernel:, process:, stderr:)
      @kernel = kernel
      @process = process
      @stderr = stderr
    end

    def ensure_available!
      return if @kernel.system('which fzf', out: '/dev/null', err: '/dev/null')

      raise "fzf is required, you can install it on macOS with 'brew install fzf'"
    end

    # Returns a [category, new_category?] pair. When the user selects the
    # sentinel entry they are prompted for a free-form name instead.
    def pick(existing_categories)
      selected = run_fzf(existing_categories + [NEW_CATEGORY_LABEL])
      return [prompt_for_new_category, true] if selected == NEW_CATEGORY_LABEL

      [selected, false]
    end

    private

    def run_fzf(options)
      out_reader, out_writer = IO.pipe
      in_reader, in_writer = IO.pipe
      pid = @process.spawn('fzf', { out: out_writer, in: in_reader })
      in_reader.close
      out_writer.close
      in_writer.puts options.join("\n")
      in_writer.close
      @process.waitpid(pid)
      out_reader.gets.chomp.tap { out_reader.close }
    rescue Errno::EPIPE => e
      @stderr.puts "Pipe issue: #{e}"
      throw :exit
    end

    def prompt_for_new_category
      Readline.readline('New category > ').downcase
    end

  end
end
