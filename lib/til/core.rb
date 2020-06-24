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

    def initialize(kernel = Kernel)
      @kernel = kernel
    end

    def run
      check_dependencies
    end

    private

    def check_dependencies
      result = @kernel.system('which fzf', out: '/dev/null', err: '/dev/null')
      unless result
        raise "fzf is required, you can install it on macOS with 'brew install fzf'"
      end
    end

  end
end
