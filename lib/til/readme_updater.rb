require 'cgi/escape'

module Til
  # Inserts a TIL link into the README while keeping its two coupled regions in
  # sync. The document has a fixed layout that this class edits by character
  # offset:
  #
  #   # TIL
  #   ---                      <- first delimiter
  #   ### Categories           <- sorted bullet index of every category
  #   * [Git](#git)
  #   ---                      <- second delimiter, closes the index
  #   ### Git                  <- one section per category, holding its links
  #   - [a](git/...)
  #
  # Adding to an existing category only touches that section; adding a new
  # category also splices a bullet into the index and a section into the body,
  # both at the alphabetically correct spot.
  class ReadmeUpdater

    CATEGORIES_HEADER = '### Categories'
    SECTION_MARKER = '###'
    DELIMITER = '---'

    Category = Struct.new(:link, :title, :slug)

    def initialize(content)
      @content = content
    end

    def add_item_for_existing_category(slug, item_title, filename)
      category = categories.find { |c| c.slug == slug }
      section_start = @content.index("#{SECTION_MARKER} #{category.title}")
      next_section_start = @content.index(SECTION_MARKER, section_start + 1)
      new_line = link_line(slug, item_title, filename)

      if next_section_start
        cut = next_section_start - 2
        @content[0..cut] + new_line + @content[cut..]
      else
        @content + new_line + "\n"
      end
    end

    def add_item_for_new_category(slug, item_title, filename)
      ordered = categories
      position = ordered.bsearch_index { |c| c.slug >= slug } || ordered.length
      ordered.insert(position, build_category(slug))

      head = @content[0..(first_delimiter + DELIMITER.length - 1)] + "\n\n#{render_index(ordered)}\n"
      new_section = "\n#{SECTION_MARKER} #{slug.capitalize}\n\n#{link_line(slug, item_title, filename)}\n"
      next_section_start = section_start_at(position)

      if next_section_start
        head + @content[index_region_end..(next_section_start - 2)] + new_section + "\n" +
          @content[next_section_start..]
      else
        head + @content[index_region_end..] + new_section
      end
    end

    private

    # The sorted bullet list that lives under "### Categories".
    def render_index(categories)
      "#{CATEGORIES_HEADER}\n\n" + categories.map { |c| "* #{c.link}" }.join("\n")
    end

    def categories
      region = @content[categories_region_start..index_region_end]
      region.scan(/(\[(\w+)\]\(#(\w+)\))/).map { |match| Category.new(*match) }
    end

    def build_category(slug)
      Category.new("[#{slug.capitalize}](##{slug})", slug.capitalize, slug)
    end

    def link_line(slug, title, filename)
      "- [#{title}](#{slug}/#{CGI.escape(filename)})"
    end

    # Walks past the index to the body section that should follow the newly
    # inserted one, i.e. the section at +position+ in document order, or nil
    # when the new category sorts last.
    def section_start_at(position)
      cursor = index_region_end + 1 + DELIMITER.length
      position.times { cursor = @content.index(SECTION_MARKER, cursor + 1) }
      @content.index(SECTION_MARKER, cursor + 1)
    end

    def categories_region_start
      @content.index(CATEGORIES_HEADER) + CATEGORIES_HEADER.length
    end

    def first_delimiter
      @content.index(DELIMITER)
    end

    # Last character before the second delimiter, which closes the index.
    def index_region_end
      @content.index(DELIMITER, first_delimiter + 1) - 1
    end

  end
end
