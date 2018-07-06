require 'rspec/bash'

describe 'n8l::git_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::git_check' }

  context 'version good' do
    it 'prints version OK' do
      stubbed_env.stub_command('hash') # confirm git is in PATH
      stubbed_env.stub_command('git').outputs('git version 2.13.4')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
      )

      expect(out).to eq("Detected git version 2.13.4. OK.\n")
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end

    context 'batch mode' do
      it 'prints version OK' do
        stubbed_env.stub_command('hash') # confirm git is in PATH
        stubbed_env.stub_command('git').outputs('git version 2.13.4')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
          { 'BATCH_FLAG' => 'true' },
        )

        expect(out).to eq("Detected git version 2.13.4. OK.\n")
        expect(err).to eq('')
        expect(status.exitstatus).to be 0
      end
    end
  end

  context 'version bad' do
    it 'prints warning' do
      stubbed_env.stub_command('hash') # confirm git is in PATH
      stubbed_env.stub_command('git').outputs('git version 1.8.2')
      stubbed_env.stub_command('read')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'yn' => 'y' },
      )
      expect(out).to match('Detected git version 1.8.2')
      expect(out).to match('Continuing without git')
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end

    it 'prints warning' do
      stubbed_env.stub_command('hash') # confirm git is in PATH
      stubbed_env.stub_command('git').outputs('git version 1.8.2')
      stubbed_env.stub_command('read')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'yn' => 'n' },
      )
      expect(out).to match('Detected git version 1.8.2')
      expect(out).to match('Okay install git and rerun the script.')
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end

    context 'batch mode' do
      it 'prints nothing' do
        stubbed_env.stub_command('hash') # confirm git is in PATH
        stubbed_env.stub_command('git').outputs('git version 1.8.2')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
          { 'BATCH_FLAG' => 'true' },
        )

        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to be 0
      end
    end
  end
end
