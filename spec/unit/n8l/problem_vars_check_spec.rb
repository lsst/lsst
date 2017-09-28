require 'rspec/bash'

describe 'n8l::problem_vars_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::problem_vars_check' }

  let(:problems) do
    %w[
      EUPS_PATH
      EUPS_PKGROOT
      REPOSITORY_PATH
    ]
  end

  context 'no problematic vars defined' do
    it 'reports nothing' do
      problem_vars = stubbed_env.stub_command('n8l::problem_vars')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
      )

      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to be 0

      expect(problem_vars).to be_called
    end
  end

  context 'problematic vars defined' do
    it 'prints multiple params to stderr' do
      problem_vars = stubbed_env.stub_command('n8l::problem_vars').outputs(
        problems.join(' ')
      )

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          #{problems.collect { |var| "#{var}=foo;" }.join(' ')}
          #{func}
        SCRIPT
      )

      expect(out).to eq('')
      problems.each { |var| expect(err).to match(/#{var}="foo"/) }
      expect(status.exitstatus).to_not be 0

      expect(problem_vars).to be_called
    end
  end
end
