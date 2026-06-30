require 'test_helper'

describe Til::Environment do
  def build(env)
    @stderr = StringIO.new
    Til::Environment.new(env: env, stderr: @stderr)
  end

  describe 'token' do
    it 'returns the preferred variable without warning' do
      env = build('TIL_RB_GITHUB_TOKEN' => 'abc')
      assert_equal 'abc', env.token
      assert_empty @stderr.string
    end

    it 'falls back to GH_TOKEN with a deprecation warning' do
      env = build('GH_TOKEN' => 'legacy')
      assert_equal 'legacy', env.token
      assert_match 'Using GH_TOKEN is deprecated, use TIL_RB_GITHUB_TOKEN instead', @stderr.string
    end

    it 'prefers the new variable over the legacy one' do
      env = build('TIL_RB_GITHUB_TOKEN' => 'new', 'GH_TOKEN' => 'legacy')
      assert_equal 'new', env.token
      assert_empty @stderr.string
    end

    it 'raises a descriptive error when both are missing' do
      error = assert_raises(RuntimeError) { build({}).token }
      assert_match 'The TIL_RB_GITHUB_TOKEN (with the public_repo or repo scope) environment variable is required',
                   error.message
    end

    it 'treats an empty string as missing' do
      error = assert_raises(RuntimeError) { build('TIL_RB_GITHUB_TOKEN' => '').token }
      assert_match 'TIL_RB_GITHUB_TOKEN', error.message
    end
  end

  describe 'repo' do
    it 'returns the preferred variable' do
      assert_equal 'a/b', build('TIL_RB_GITHUB_REPO' => 'a/b').repo
    end

    it 'falls back to GH_REPO with a deprecation warning' do
      env = build('GH_REPO' => 'a/b')
      assert_equal 'a/b', env.repo
      assert_match 'Using GH_REPO is deprecated, use TIL_RB_GITHUB_REPO instead', @stderr.string
    end

    it 'raises when missing' do
      error = assert_raises(RuntimeError) { build({}).repo }
      assert_match 'The TIL_RB_GITHUB_REPO environment variable is required', error.message
    end
  end

  describe 'validate!' do
    it 'checks the token before the repo' do
      error = assert_raises(RuntimeError) { build('TIL_RB_GITHUB_REPO' => 'a/b').validate! }
      assert_match 'TIL_RB_GITHUB_TOKEN', error.message
    end

    it 'returns itself when everything resolves' do
      env = build('TIL_RB_GITHUB_TOKEN' => 'abc', 'TIL_RB_GITHUB_REPO' => 'a/b')
      assert_same env, env.validate!
    end
  end
end
