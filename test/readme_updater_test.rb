require 'test_helper'
require 'timecop'

describe Til::ReadmeUpdater do

  before do
    @initial_content = <<~CONTENT
    # TIL

    ---

    ### Categories

    * [Git](#git)
    * [Javascript](#javascript)

    ---

    ### Git

    - [a](git/2020-06-16_a.md)

    ### Javascript

    - [c](javascript/2020-06-21_c.md)
    CONTENT
  end

  describe 'add_item_for_existing_category' do
    it 'works with a category that is not last' do
      updater = Til::ReadmeUpdater.new(@initial_content)
      expected_string = <<~CONTENT
      # TIL

      ---

      ### Categories

      * [Git](#git)
      * [Javascript](#javascript)

      ---

      ### Git

      - [a](git/2020-06-16_a.md)
      - [e](git/2020-06-24_e.md)

      ### Javascript

      - [c](javascript/2020-06-21_c.md)
      CONTENT

      assert_equal(expected_string, updater.add_item_for_existing_category('git', 'e', '2020-06-24_e.md'))
    end

    it 'works with the last category' do
      updater = Til::ReadmeUpdater.new(@initial_content)
      expected_string = <<~CONTENT
      # TIL

      ---

      ### Categories

      * [Git](#git)
      * [Javascript](#javascript)

      ---

      ### Git

      - [a](git/2020-06-16_a.md)

      ### Javascript

      - [c](javascript/2020-06-21_c.md)
      - [e](javascript/2020-06-24_e.md)
      CONTENT

      assert_equal(expected_string, updater.add_item_for_existing_category('javascript', 'e', '2020-06-24_e.md'))
    end

  end

  describe 'add_item_for_new_category' do
    it 'works with a category that does not end up last'
    it 'works with a category that ends up last'
  end
end
