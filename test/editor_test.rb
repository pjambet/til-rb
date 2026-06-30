require 'test_helper'

describe Til::Editor do
  # Stands in for the user's editor: records how it was invoked, captures the
  # seeded template, and optionally simulates the user saving new content.
  class FakeKernel
    attr_reader :invocation, :seeded_content

    def initialize(saves: nil)
      @saves = saves
    end

    def system(*args)
      @invocation = args
      @seeded_content = File.read(args.last)
      File.write(args.last, @saves) if @saves
      true
    end
  end

  it 'seeds the template with the given title and category' do
    kernel = FakeKernel.new
    Til::Editor.new(env: {}, kernel: kernel).capture(category: 'ruby', title: 'My Title')

    assert_equal "# My Title\n\nWhat did you learn about ruby today", kernel.seeded_content
  end

  it 'uses a placeholder title when none is provided' do
    kernel = FakeKernel.new
    Til::Editor.new(env: {}, kernel: kernel).capture(category: 'ruby', title: nil)

    assert_equal "# Title Placeholder\n\nWhat did you learn about ruby today", kernel.seeded_content
  end

  it 'returns the content the user saved' do
    kernel = FakeKernel.new(saves: "# Done\n\nbody")
    content = Til::Editor.new(env: {}, kernel: kernel).capture(category: 'ruby', title: 'X')

    assert_equal "# Done\n\nbody", content
  end

  it 'removes the scratch file afterwards' do
    kernel = FakeKernel.new
    Til::Editor.new(env: {}, kernel: kernel).capture(category: 'ruby', title: 'X')

    refute File.exist?(kernel.invocation.last)
  end

  describe 'editor selection' do
    it 'prefers $VISUAL and splits its arguments' do
      kernel = FakeKernel.new
      env = { 'VISUAL' => 'code -w', 'EDITOR' => 'nano' }
      Til::Editor.new(env: env, kernel: kernel).capture(category: 'ruby', title: 'X')

      assert_equal ['code', '-w'], kernel.invocation[0..1]
    end

    it 'falls back to $EDITOR' do
      kernel = FakeKernel.new
      Til::Editor.new(env: { 'EDITOR' => 'nano' }, kernel: kernel).capture(category: 'ruby', title: 'X')

      assert_equal 'nano', kernel.invocation.first
    end

    it 'defaults to vi' do
      kernel = FakeKernel.new
      Til::Editor.new(env: {}, kernel: kernel).capture(category: 'ruby', title: 'X')

      assert_equal 'vi', kernel.invocation.first
    end
  end
end
