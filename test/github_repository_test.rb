require 'test_helper'
require 'base64'

describe Til::GitHubRepository do
  Sha = Struct.new(:sha)
  Ref = Struct.new(:object)
  Commit = Struct.new(:commit)
  CommitBody = Struct.new(:tree)
  TreeListing = Struct.new(:tree)
  Readme = Struct.new(:content)

  NAME = 'pjambet/til'

  def build(client)
    Til::GitHubRepository.new(client: client, name: NAME)
  end

  describe 'category_names' do
    it 'returns only the directory entries' do
      client = mock
      client.expects(:contents).with(NAME, path: '').returns([
        { 'type' => 'dir', name: 'git' },
        { 'type' => 'file', name: 'README.md' },
        { 'type' => 'dir', name: 'ruby' },
      ])

      assert_equal %w(git ruby), build(client).category_names
    end
  end

  describe 'readme_content' do
    it 'base64-decodes the README payload' do
      client = mock
      client.expects(:readme).with(NAME).returns(Readme.new(Base64.encode64('hello')))

      assert_equal 'hello', build(client).readme_content
    end
  end

  describe 'commit_til' do
    it 'builds a commit that preserves other files and rewrites the README' do
      client = mock
      client.expects(:ref).with(NAME, 'heads/master').returns(Ref.new(Sha.new('base-sha')))
      client.expects(:commit).with(NAME, 'base-sha').returns(Commit.new(CommitBody.new(Sha.new('tree-sha'))))
      client.expects(:tree).with(NAME, 'tree-sha', recursive: true).returns(TreeListing.new([
        { type: 'blob', path: 'README.md', mode: '100644', sha: 'old-readme' },
        { type: 'blob', path: 'git/a.md', mode: '100644', sha: 'keep' },
        { type: 'tree', path: 'git', mode: '040000', sha: 'dir' },
      ]))
      client.expects(:create_blob).with(NAME, 'new readme').returns('readme-blob')
      client.expects(:create_blob).with(NAME, 'til body').returns('til-blob')

      expected_tree = [
        { path: 'git/a.md', mode: '100644', type: 'blob', sha: 'keep' },
        { path: 'README.md', mode: '100644', type: 'blob', sha: 'readme-blob' },
        { path: 'ruby/2020-06-25_x.md', mode: '100644', type: 'blob', sha: 'til-blob' },
      ]
      client.expects(:create_tree).with(NAME, expected_tree).returns(Sha.new('new-tree'))
      client.expects(:create_commit).with(NAME, 'X', 'new-tree', 'base-sha').returns(Sha.new('new-commit'))
      client.expects(:update_ref).with(NAME, 'heads/master', 'new-commit')

      build(client).commit_til(
        title: 'X',
        category: 'ruby',
        filename: '2020-06-25_x.md',
        til_content: 'til body',
        readme_content: 'new readme',
      )
    end
  end
end
