require 'test_helper'

describe Til do
  it 'has a run method' do
    Til::Core.run
  end

  it 'exits if fzf is not available' do
    error = assert_raises RuntimeError do
      kernel_mock = Minitest::Mock.new
      kernel_mock.expect :system, false, ['which fzf', { out: '/dev/null', err: '/dev/null' }]
      Til::Core.new(kernel_mock).run
    end
    assert_match(/fzf is required, you can install it on macOS with 'brew install fzf'/, error.message)
  end
end
