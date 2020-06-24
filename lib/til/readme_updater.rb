module Til
  class ReadmeUpdater

    def initialize(initial_content)
      @initial_content = initial_content
    end

    def add_item_for_existing_category(category, item_title, filename)
      beginning = @initial_content.index('### Categories') + '### Categories'.length
      eend = @initial_content.index('---', @initial_content.index('---') + 1) - 1

      # [["[Git](#git)", "Git", "git"], ["[Qux](#qux)", "Qux", "qux"]]
      categories = @initial_content[beginning..eend].scan(/(\[(\w+)\]\(#(\w+)\))/)

      existing_cat = categories.find { |c| c[2] == category }

      loc_in_page = @initial_content.index("### #{existing_cat[1]}")
      next_cat_location = @initial_content.index('###', loc_in_page + 1)

      new_line = "- [#{item_title}](#{category}/#{filename})"
      new_readme_content = ''
      if next_cat_location
        breakpoint = next_cat_location - 2
        new_readme_content = @initial_content[0..breakpoint] + new_line + @initial_content[breakpoint..]
      else
        new_readme_content = @initial_content + new_line + "\n"
      end
      new_readme_content
    end

    def add_item_for_new_category(category, item_title)
    end
  end
end
