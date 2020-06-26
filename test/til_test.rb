require 'test_helper'
require 'timecop'

describe Til::Core do
  it 'has a run method' do
    github_client_mock = Minitest::Mock.new
    github_client_mock.expect :contents, [], ['pjambet/til', { path: '' }]

    Process.stubs(:spawn).returns(12)

    Til::Core.new(
      process: Process,
      stderr: StringIO.new,
      env: { 'GH_TOKEN' => 'abc', 'GH_REPO' => 'pjambet/til' },
      github_client: github_client_mock,
    ).run
  end

  it 'exits if GH_TOKEN is nil or empty' do
    error = assert_raises RuntimeError do
      Til::Core.new(env: {}).run
    end
    assert_match 'The GH_TOKEN (with the public_repo or repo scope) environment variable is required', error.message
  end

  it 'exits if GH_REPO is nil or empty' do
    error = assert_raises RuntimeError do
      Til::Core.new(env: { 'GH_TOKEN' => 'abc' }).run
    end
    assert_match 'The GH_REPO environment variable is required', error.message
  end

  it 'exits if fzf is not available' do
    error = assert_raises RuntimeError do
      kernel_mock = Minitest::Mock.new
      kernel_mock.expect :system, false, ['which fzf', { out: '/dev/null', err: '/dev/null' }]
      Til::Core.new(kernel: kernel_mock, env: { 'GH_TOKEN' => 'abc' }).run
    end
    assert_match "fzf is required, you can install it on macOS with 'brew install fzf'", error.message
  end

  it 'escapes URLs in filenames' do
    # Yeah yeah, I'm testing a private methode, it's 'wrong', but *shrug*
    til = Til::Core.new(
      env: { 'GH_TOKEN' => 'abc', 'GH_REPO' => 'pjambet/til' },
    )

    Timecop.freeze(Time.local(2020, 6, 25, 12, 0, 0)) do
      filename = til.send :new_filename, 'Ruby 2.7 adds Enumerable#filter_map'

      assert_equal '2020-06-25_ruby-2.7-adds-enumerable%23filter_map.md', filename
    end
  end
end
