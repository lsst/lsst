# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::problem_vars' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::problem_vars' }

  let(:problems) do
    %w[
      EUPS_PATH
      EUPS_PKGROOT
      REPOSITORY_PATH
    ]
  end

  context 'no problematic vars defined' do
    it 'reports nothing' do
      problems.each { |var| ENV.delete(var) }

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          unset #{problems.join(' ')}
          #{func}
        SCRIPT
      )

      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end
  end

  context 'problematic vars defined' do
    it 'prints multiple params to stderr' do
      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          #{problems.collect { |var| "#{var}=foo;" }.join(' ')}
          #{func}
        SCRIPT
      )

      expect(out).to eq(problems.join(' '))
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end
  end
end
