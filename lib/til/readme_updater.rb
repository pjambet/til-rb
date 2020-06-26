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

      new_line = "- [#{item_title}](#{category}/#{CGI.escape(filename)})"
      new_readme_content = ''
      if next_cat_location
        breakpoint = next_cat_location - 2
        new_readme_content = @initial_content[0..breakpoint] + new_line + @initial_content[breakpoint..]
      else
        new_readme_content = @initial_content + new_line + "\n"
      end
      new_readme_content
    end

    def add_item_for_new_category(category, item_title, filename)
      # TODO: We'll need some form of validation on the category name
      beginning = @initial_content.index('### Categories') + '### Categories'.length
      first_dashdashdash = @initial_content.index('---')
      eend = @initial_content.index('---', first_dashdashdash + 1) - 1

      # [["[Git](#git)", "Git", "git"], ["[Qux](#qux)", "Qux", "qux"]]
      categories = @initial_content[beginning..eend].scan(/(\[(\w+)\]\(#(\w+)\))/)

      insert_at = categories.bsearch_index do |category_triplet|
        category_triplet[2] >= category
      end

      if insert_at.nil?
        # It's the last category
        insert_at = categories.length
      end

      categories.insert(insert_at, ["[#{category.capitalize}](\##{category})", category.capitalize, category])

      new_categories_formatted = categories.map do |category|
        "* #{category[0]}"
      end.join("\n")

      new_categories_formatted.prepend("### Categories\n\n")

      category_sections_found = 0
      current_search_index = eend + 1 + 3

      while category_sections_found < insert_at
        current_search_index = @initial_content.index('###', current_search_index + 1)
        category_sections_found += 1
      end

      next_bound = @initial_content.index('###', current_search_index + 1)

      new_line = "- [#{item_title}](#{category}/#{CGI.escape(filename)})"

      if next_bound
        new_readme_content = @initial_content[0..(first_dashdashdash + 2)] \
                             + "\n\n#{new_categories_formatted}\n" \
                             + @initial_content[eend..(next_bound - 2)] \
                             + "\n### #{category.capitalize}\n\n#{new_line}\n\n" \
                             + @initial_content[next_bound..]
      else
        new_readme_content = @initial_content[0..(first_dashdashdash + 2)] \
                             + "\n\n#{new_categories_formatted}\n" \
                             + @initial_content[eend..] \
                             + "\n### #{category.capitalize}\n\n#{new_line}\n"
      end

      new_readme_content
    end
  end
end
