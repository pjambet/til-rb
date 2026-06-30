require 'test_helper'

describe Til::CategoryPicker do
  # fzf is never really launched in these tests; spawning a no-op process means
  # nothing reads the pipe, which exercises the broken-pipe path.
  class FakeProcess
    def spawn(*)
      12_345
    end

    def waitpid(_pid); end
  end

  def build(kernel: nil, process: FakeProcess.new, stderr: StringIO.new)
    @stderr = stderr
    Til::CategoryPicker.new(kernel: kernel, process: process, stderr: stderr)
  end

  describe 'ensure_available!' do
    it 'is a no-op when fzf is installed' do
      kernel = mock
      kernel.expects(:system).with('which fzf', out: '/dev/null', err: '/dev/null').returns(true)

      build(kernel: kernel).ensure_available!
    end

    it 'raises when fzf is missing' do
      kernel = mock
      kernel.expects(:system).with('which fzf', out: '/dev/null', err: '/dev/null').returns(false)

      error = assert_raises(RuntimeError) { build(kernel: kernel).ensure_available! }
      assert_match "fzf is required, you can install it on macOS with 'brew install fzf'", error.message
    end
  end

  describe 'pick' do
    it 'returns the selected category as existing' do
      picker = build
      picker.stubs(:run_fzf).returns('git')

      assert_equal ['git', false], picker.pick(['git', 'ruby'])
    end

    it 'offers the sentinel entry alongside the known categories' do
      picker = build
      picker.expects(:run_fzf).with(['git', 'ruby', 'Something else?']).returns('git')

      picker.pick(['git', 'ruby'])
    end

    it 'prompts for a new, lower-cased category when the sentinel is chosen' do
      picker = build
      picker.stubs(:run_fzf).returns('Something else?')
      Readline.stubs(:readline).with('New category > ').returns('Bash')

      assert_equal ['bash', true], picker.pick(['git'])
    end

    it 'reports a broken pipe and bails out via throw(:exit)' do
      picker = build
      result = catch(:exit) { picker.pick(['git']); :did_not_exit }

      assert_nil result
      assert_match 'Pipe issue:', @stderr.string
    end
  end
end
