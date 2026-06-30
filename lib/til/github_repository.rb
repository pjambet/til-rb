require 'base64'

module Til
  # Wraps the handful of GitHub operations til needs, hiding the octokit
  # client and the low-level "build a tree, create a commit, move the ref"
  # dance behind a small intention-revealing interface.
  class GitHubRepository

    DEFAULT_BRANCH = 'master'

    attr_reader :name

    def initialize(client:, name:)
      @client = client
      @name = name
    end

    # Names of the top-level directories, which double as TIL categories.
    def category_names
      @client.contents(@name, path: '')
             .select { |entry| entry['type'] == 'dir' }
             .map { |entry| entry[:name] }
    end

    def readme_content
      Base64.decode64(@client.readme(@name).content)
    end

    # Commits a new TIL file and the updated README in a single commit on the
    # default branch, preserving every other existing file.
    def commit_til(title:, category:, filename:, til_content:, readme_content:)
      ref = @client.ref(@name, branch_ref)
      entries = preserved_blobs(ref.object.sha)
      entries << blob_entry('README.md', readme_content)
      entries << blob_entry("#{category}/#{filename}", til_content)

      tree = @client.create_tree(@name, entries)
      commit = @client.create_commit(@name, title, tree.sha, ref.object.sha)
      @client.update_ref(@name, branch_ref, commit.sha)
    end

    private

    def branch_ref
      "heads/#{DEFAULT_BRANCH}"
    end

    # Every existing blob except the README, which we always rewrite.
    def preserved_blobs(commit_sha)
      base_commit = @client.commit(@name, commit_sha)
      tree = @client.tree(@name, base_commit.commit.tree.sha, recursive: true)
      tree.tree
          .select { |entry| entry[:type] == 'blob' && entry[:path] != 'README.md' }
          .map { |entry| entry.to_h.slice(:path, :mode, :type, :sha) }
    end

    def blob_entry(path, content)
      { path: path, mode: '100644', type: 'blob', sha: @client.create_blob(@name, content) }
    end

  end
end
