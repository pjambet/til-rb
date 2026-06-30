require 'cgi/escape'
require 'octokit'

require 'til/environment'
require 'til/category_picker'
require 'til/editor'
require 'til/github_repository'
require 'til/readme_updater'

module Til
  # Orchestrates the end-to-end flow of capturing a TIL: it wires the
  # collaborators together and runs them in order, but delegates every concrete
  # responsibility (environment, fzf, the editor, GitHub, the README) to them.
  class Core

    def self.run(options: {})
      new(options: options).run
    end

    def initialize(options: {}, kernel: Kernel, process: Process, env: ENV, github_client: nil, stderr: $stderr)
      @options = options
      @kernel = kernel
      @process = process
      @env = env
      @stderr = stderr
      @github_client = github_client
    end

    def run
      catch(:exit) do
        category_picker.ensure_available!
        environment.validate!
        category, new_category = category_picker.pick(repository.category_names)
        content = editor.capture(category: category, title: @options[:title])
        publish(category, content, new_category)
      end
    end

    private

    def publish(category, content, new_category)
      title = extract_title(content)
      filename = new_filename(title)
      updated_readme = update_readme(category, title, filename, new_category)

      repository.commit_til(
        title: title,
        category: category,
        filename: filename,
        til_content: content,
        readme_content: updated_readme,
      )
      print_locations(category, filename)
    end

    def extract_title(content)
      first_line = content.lines.first.to_s.chomp
      first_line.start_with?('#') ? first_line[1..].strip : first_line
    end

    def new_filename(title)
      date = Time.now.strftime('%Y-%m-%d')
      slug = title.split.map(&:downcase).join('-')
      "#{date}_#{slug}.md"
    end

    def update_readme(category, title, filename, new_category)
      updater = ReadmeUpdater.new(repository.readme_content)
      if new_category
        updater.add_item_for_new_category(category, title, filename)
      else
        updater.add_item_for_existing_category(category, title, filename)
      end
    end

    def print_locations(category, filename)
      escaped = CGI.escape(filename)
      branch = GitHubRepository::DEFAULT_BRANCH
      base = "https://github.com/#{repository.name}"
      puts "You can see your new TIL at : #{base}/blob/#{branch}/#{category}/#{escaped}"
      puts "You can edit your new TIL at : #{base}/edit/#{branch}/#{category}/#{escaped}"
    end

    def environment
      @environment ||= Environment.new(env: @env, stderr: @stderr)
    end

    def category_picker
      @category_picker ||= CategoryPicker.new(kernel: @kernel, process: @process, stderr: @stderr)
    end

    def editor
      @editor ||= Editor.new(env: @env, kernel: @kernel)
    end

    def repository
      @repository ||= GitHubRepository.new(client: github_client, name: environment.repo)
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: environment.token)
    end

  end
end
