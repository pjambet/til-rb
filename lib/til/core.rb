require 'octokit'
require 'tempfile'

module Til
  class Core

    def self.run
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
      til = new
      til.run
    end

    def initialize(kernel: Kernel, process: Process, env: ENV, github_client: nil, stderr: $stderr)
      @kernel = kernel
      @process = process
      @env = env
      @stderr = stderr
      @github_client = github_client
      @repo_name = 'pjambet/til'
      @new_category = false
    end

    def run
      catch(:exit) do
        check_dependencies
        check_environment_variables
        existing_categories = fetch_existing_categories
        selected_category = prompt_fzf(existing_categories)
        prepopulate_tempfile(selected_category)
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
      if @env['GH_TOKEN'].nil? || @env['GH_TOKEN'] == ''
        raise 'The GH_TOKEN (with the public_repo or repo scope) environment variable is required'
      end

      if (@env['VISUAL'].nil? || @env['VISUAL'] == '') && (@env['EDITOR'].nil? || @env['EDITOR'] == '')
        raise 'The VISUAL or EDITOR environment variables are required'
      end
    end

    def fetch_existing_categories
      existing_categories = github_client.contents(@repo_name, path: '').filter do |c|
        c['type'] == 'dir'
      end

      existing_category_names = existing_categories.map do |category|
        category[:name]
      end

      existing_category_names << 'Something else?'
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: @env['GH_TOKEN'])
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

    def prepopulate_tempfile(selected_category, title = 'Title Placeholder')
      @tempfile = Tempfile.new('til.md')
      @tempfile.write("# #{title}")
      @tempfile.write("\n" * 2)
      @tempfile.write("What did you learn about #{selected_category} today")
      @tempfile.close
    end

    def open_editor
      editor = ENV['VISUAL'] || ENV['EDITOR']
      system(*editor.split, @tempfile.path)
    end

    def read_file
      content = File.read(@tempfile)
      @tempfile.unlink
      content
    end

    def commit_new_til(category, content)
      commit_title = content.lines[0].chomp
      if commit_title.start_with?('#')
        commit_title = commit_title[1..].strip
      end
      today = Time.now.strftime '%Y-%m-%d'
      name = commit_title.split.map(&:downcase).join('-')
      filename = "#{today}_#{name}.md"

      ref = github_client.ref @repo_name, 'heads/master'
      commit = github_client.commit @repo_name, ref.object.sha
      tree = github_client.tree @repo_name, commit.commit.tree.sha, recursive: true
      readme = github_client.readme @repo_name
      readme_content = Base64.decode64 readme.content

      blob = github_client.create_blob @repo_name, content
      blobs = tree.tree.filter { |object|
        object[:type] == 'blob' && object[:path] != 'README.md'
      }.map { |object|
        object.to_h.slice(:path, :mode, :type, :sha)
      }

      updated_readme_content = update_readme_content(category, commit_title, filename, readme_content)
      new_readme_blob = github_client.create_blob @repo_name, updated_readme_content
      blobs << { path: 'README.md', mode: '100644', type: 'blob', sha: new_readme_blob }

      blobs << { path: "#{category}/#{filename}", mode: '100644', type: 'blob', sha: blob }

      tree = github_client.create_tree @repo_name, blobs
      commit = github_client.create_commit @repo_name, commit_title, tree.sha, ref.object.sha
      github_client.update_ref @repo_name, 'heads/master', commit.sha

      puts "You can see your new TIL at : https://github.com/pjambet/til/blob/master/#{category}/#{filename}"
      puts "You can edit your new TIL at : https://github.com/pjambet/til/edit/master/#{category}/#{filename}"
    end

    def update_readme_content(category, commit_title, filename, readme_content)
      beginning = readme_content.index('### Categories') + '### Categories'.length
      eend = readme_content.index('---', readme_content.index('---') + 1) - 1

      # [["[Git](#git)", "Git", "git"], ["[Qux](#qux)", "Qux", "qux"]]
      categories = readme_content[beginning..eend].scan(/(\[(\w+)\]\(#(\w+)\))/)

      if @new_category
      else
        existing_cat = categories.find { |c| c[2] == category }

        loc_in_page = readme_content.index("### #{existing_cat[1]}")
        next_cat_location = readme_content.index('###', loc_in_page + 1)

        new_line = "- [#{commit_title}](#{category}/#{filename})"
        new_readme_content = ''
        if next_cat_location
          breakpoint = next_cat_location - 2
          new_readme_content = readme_content[0..breakpoint] + new_line + readme_content[breakpoint..]
        else
          new_readme_content = readme_content + new_line + '\n'
        end
        new_readme_content
      end
    end

  end
end
