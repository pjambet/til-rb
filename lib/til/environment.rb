module Til
  # Resolves the GitHub token and repository from the process environment.
  #
  # The current variable names are preferred, but the original GH_TOKEN /
  # GH_REPO names are still honoured with a deprecation warning so existing
  # setups keep working.
  class Environment

    TOKEN_VAR = 'TIL_RB_GITHUB_TOKEN'
    REPO_VAR = 'TIL_RB_GITHUB_REPO'
    LEGACY_TOKEN_VAR = 'GH_TOKEN'
    LEGACY_REPO_VAR = 'GH_REPO'

    def initialize(env:, stderr:)
      @env = env
      @stderr = stderr
    end

    def token
      @token ||= require_var(TOKEN_VAR, LEGACY_TOKEN_VAR, ' (with the public_repo or repo scope)')
    end

    def repo
      @repo ||= require_var(REPO_VAR, LEGACY_REPO_VAR)
    end

    # Forces resolution of both variables so a missing one fails fast, and
    # always in the same order (token before repo).
    def validate!
      token
      repo
      self
    end

    private

    def require_var(name, legacy_name, qualifier = '')
      preferred = presence(@env[name])
      return preferred if preferred

      legacy = presence(@env[legacy_name])
      if legacy
        @stderr.puts "Using #{legacy_name} is deprecated, use #{name} instead"
        return legacy
      end

      raise "The #{name}#{qualifier} environment variable is required"
    end

    def presence(value)
      value unless value.nil? || value.empty?
    end

  end
end
