require 'octokit'
require 'tempfile'
require 'readline'

module Til
  class Core

    GH_TOKEN_ENV_VAR_NAME = 'TIL_RB_GITHUB_TOKEN'
    GH_REPO_ENV_VAR_NAME = 'TIL_RB_GITHUB_REPO'

    def self.run(options: {})
      # Exit if `fzf` is not available
      # Optionally print a spinner
      # Grab the list of existing categories
      # Feed them into fzf with a new entry to let the user type a category
      # Grab the category from fzf
      # Handle the case where it's a new category (as in, figure out the new place in the README)
      # Open $VISUAL or $EDITOR with a tempfile
      # Read the file content
      # Update the README.md with a link to the new entry
      # Create the new file
      # Create a new commit
      # Output a link to the file and the link to edit it
      til = new(options: options)
      til.run
    end

    def initialize(options: {}, kernel: Kernel, process: Process, env: ENV, github_client: nil, stderr: $stderr)
      @options = options
      @kernel = kernel
      @process = process
      @env = env
      @stderr = stderr
      @github_client = github_client
      @repo_name = nil
      @new_category = false
    end

    def run
      catch(:exit) do
        check_dependencies
        check_environment_variables
        existing_categories = fetch_existing_categories
        selected_category = prompt_fzf(existing_categories)
        if @new_category
          selected_category = prompt_for_new_category
        end
        prepopulate_tempfile(selected_category, @options[:title])
        open_editor
        til_content = read_file
        commit_new_til(selected_category, til_content)
      end
    end

    private

    def check_dependencies
      result = @kernel.system('which fzf', out: '/dev/null', err: '/dev/null')
      unless result
        raise "fzf is required, you can install it on macOS with 'brew install fzf'"
      end
    end

    def check_environment_variables
      if @env[GH_TOKEN_ENV_VAR_NAME].nil? || @env[GH_TOKEN_ENV_VAR_NAME] == ''
        if @env['GH_TOKEN'].nil? || @env['GH_TOKEN'] == ''
          raise "The #{GH_TOKEN_ENV_VAR_NAME} (with the public_repo or repo scope) environment variable is required"
        else
          @stderr.puts "Using GH_TOKEN is deprecated, use #{GH_TOKEN_ENV_VAR_NAME} instead"
        end
      end

      if @env[GH_REPO_ENV_VAR_NAME].nil? || @env[GH_REPO_ENV_VAR_NAME] == ''
        if @env['GH_REPO'].nil? || @env['GH_REPO'] == ''
          raise "The #{GH_REPO_ENV_VAR_NAME} environment variable is required"
        else
          @stderr.puts "Using GH_REPO is deprecated, use #{GH_REPO_ENV_VAR_NAME} instead"
        end
      end
    end

    def fetch_existing_categories
      existing_categories = github_client.contents(repo_name, path: '').filter do |c|
        c['type'] == 'dir'
      end

      existing_category_names = existing_categories.map do |category|
        category[:name]
      end

      existing_category_names << 'Something else?'
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: @env[GH_TOKEN_ENV_VAR_NAME] || @env['GH_TOKEN'])
    end

    def repo_name
      @repo_name ||= (@env[GH_REPO_ENV_VAR_NAME] || @env['GH_REPO'])
    end

    def prompt_fzf(categories)
      reader1, writer1 = IO.pipe
      reader2, writer2 = IO.pipe
      fzf_pid = @process.spawn('fzf', { out: writer1, in: reader2 })
      reader2.close
      writer1.close
      writer2.puts categories.join("\n")
      writer2.close
      Process.waitpid(fzf_pid)
      selected = reader1.gets.chomp
      reader1.close
      if selected == 'Something else?'
        @new_category = true
      end
      selected
    rescue Errno::EPIPE => e
      @stderr.puts "Pipe issue: #{e}"
      throw :exit
    end

    def prompt_for_new_category
      Readline.readline("New category > ").downcase
    end

    def prepopulate_tempfile(selected_category, title = 'Title Placeholder')
      @tempfile = Tempfile.new('til.md')
      @tempfile.write("# #{title}")
      @tempfile.write("\n" * 2)
      @tempfile.write("What did you learn about #{selected_category} today")
      @tempfile.close
    end

    def open_editor
      editor = ENV['VISUAL'] || ENV['EDITOR'] || 'vi'
      system(*editor.split, @tempfile.path)
    end

    def read_file
      content = File.read(@tempfile)
      @tempfile.unlink
      content
    end

    def new_filename(commit_title)
      today = Time.now.strftime '%Y-%m-%d'
      name = commit_title.split.map(&:downcase).join('-')
      "#{today}_#{name}.md"
    end

    def commit_new_til(category, content)
      commit_title = content.lines[0].chomp
      if commit_title.start_with?('#')
        commit_title = commit_title[1..].strip
      end
      filename = new_filename(commit_title)

      ref = github_client.ref repo_name, 'heads/master'
      commit = github_client.commit repo_name, ref.object.sha
      tree = github_client.tree repo_name, commit.commit.tree.sha, recursive: true
      readme = github_client.readme repo_name
      readme_content = Base64.decode64 readme.content

      blob = github_client.create_blob repo_name, content
      blobs = tree.tree.filter { |object|
        object[:type] == 'blob' && object[:path] != 'README.md'
      }.map { |object|
        object.to_h.slice(:path, :mode, :type, :sha)
      }

      updated_readme_content = update_readme_content(category, commit_title, filename, readme_content)
      new_readme_blob = github_client.create_blob repo_name, updated_readme_content
      blobs << { path: 'README.md', mode: '100644', type: 'blob', sha: new_readme_blob }

      blobs << { path: "#{category}/#{filename}", mode: '100644', type: 'blob', sha: blob }

      tree = github_client.create_tree repo_name, blobs
      commit = github_client.create_commit repo_name, commit_title, tree.sha, ref.object.sha
      github_client.update_ref repo_name, 'heads/master', commit.sha

      cgi_escaped_filename = CGI.escape(filename)
      til_url = "https://github.com/#{repo_name}/blob/master/#{category}/#{cgi_escaped_filename}"
      til_edit_url = "https://github.com/#{repo_name}/edit/master/#{category}/#{cgi_escaped_filename}"
      puts "You can see your new TIL at : #{til_url}"
      puts "You can edit your new TIL at : #{til_edit_url}"
    end

    def update_readme_content(category, commit_title, filename, readme_content)
      updater = Til::ReadmeUpdater.new(readme_content)

      if @new_category
        updater.add_item_for_new_category(category, commit_title, filename)
      else
        updater.add_item_for_existing_category(category, commit_title, filename)
      end
    end

  end
end
