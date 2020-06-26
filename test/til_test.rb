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
      env: { 'TIL_RB_GITHUB_TOKEN' => 'abc', 'TIL_RB_GITHUB_REPO' => 'pjambet/til' },
      github_client: github_client_mock,
    ).run
  end

  it 'exits if TIL_RB_GITHUB_TOKEN is nil or empty' do
    error = assert_raises RuntimeError do
      Til::Core.new(env: {}).run
    end
    assert_match 'The TIL_RB_GITHUB_TOKEN (with the public_repo or repo scope) environment variable is required',
                 error.message
  end

  it 'logs a warning if the deprecated GH_TOKEN is used' do
    Process.stubs(:spawn).returns(12)
    github_client_mock = mock
    github_client_mock.expects(:contents).with('a/b', { path: '' }).returns([]).once
    stderr = StringIO.new

    Til::Core.new(
      env: { 'GH_TOKEN' => 'abc', 'TIL_RB_GITHUB_REPO' => 'a/b' },
      stderr: stderr,
      github_client: github_client_mock,
    ).run

    stderr.rewind
    assert_match(/\AUsing GH_TOKEN is deprecated, use TIL_RB_GITHUB_TOKEN instead$/,
                 stderr.read)
  end

  it 'exits if TIL_RB_GITHUB_REPO is nil or empty' do
    error = assert_raises RuntimeError do
      Til::Core.new(env: { 'TIL_RB_GITHUB_TOKEN' => 'abc' }).run
    end
    assert_match 'The TIL_RB_GITHUB_REPO environment variable is required', error.message
  end

  it 'logs a warning if the deprecated GH_REPO is used' do
    Process.stubs(:spawn).returns(12)
    github_client_mock = mock
    github_client_mock.expects(:contents).with('a/b', { path: '' }).returns([]).once
    stderr = StringIO.new

    Til::Core.new(
      env: { 'GH_REPO' => 'a/b', 'TIL_RB_GITHUB_TOKEN' => 'abc' },
      stderr: stderr,
      github_client: github_client_mock,
    ).run

    stderr.rewind
    assert_match(/\AUsing GH_REPO is deprecated, use TIL_RB_GITHUB_REPO instead$/,
                 stderr.read)
  end

  it 'exits if fzf is not available' do
    error = assert_raises RuntimeError do
      kernel_mock = Minitest::Mock.new
      kernel_mock.expect :system, false, ['which fzf', { out: '/dev/null', err: '/dev/null' }]
      Til::Core.new(kernel: kernel_mock, env: { 'TIL_RB_GITHUB_TOKEN' => 'abc' }).run
    end
    assert_match "fzf is required, you can install it on macOS with 'brew install fzf'", error.message
  end

  it 'does not escape URLs in filenames' do
    # Yeah yeah, I'm testing a private methode, it's 'wrong', but *shrug*
    til = Til::Core.new(
      env: { 'TIL_RB_GITHUB_TOKEN' => 'abc', 'TIL_RB_GITHUB_REPO' => 'pjambet/til' },
    )

    Timecop.freeze(Time.local(2020, 6, 25, 12, 0, 0)) do
      filename = til.send :new_filename, 'Ruby 2.7 adds Enumerable#filter_map'

      assert_equal '2020-06-25_ruby-2.7-adds-enumerable#filter_map.md', filename
    end
  end
end
