require 'tempfile'

module Til
  # Prepares a Markdown scratch file seeded with a title and prompt, opens it
  # in the user's editor, and returns whatever they saved.
  class Editor

    DEFAULT_EDITOR = 'vi'
    DEFAULT_TITLE = 'Title Placeholder'

    def initialize(env:, kernel:)
      @env = env
      @kernel = kernel
    end

    def capture(category:, title:)
      path = prepopulate(category, title)
      open(path)
      content = File.read(path)
      File.unlink(path)
      content
    end

    private

    def prepopulate(category, title)
      file = Tempfile.new('til.md')
      file.write(<<~TEMPLATE.chomp)
        # #{title || DEFAULT_TITLE}

        What did you learn about #{category} today
      TEMPLATE
      file.close
      file.path
    end

    def open(path)
      editor = @env['VISUAL'] || @env['EDITOR'] || DEFAULT_EDITOR
      @kernel.system(*editor.split, path)
    end

  end
end
