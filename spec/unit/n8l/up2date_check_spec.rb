require 'rspec/bash'

describe 'n8l::up2date_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::up2date_check' }

  context 'script matches master' do
    it 'prints nothing' do
      stubbed_env.stub_command('diff').returns_exitstatus(0)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'CURL' => 'true' },
      )

      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end
  end # script matches master

  context 'script out of sync with master' do
    it 'prints a non-fatal warning' do
      stubbed_env.stub_command('diff').returns_exitstatus(1)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'CURL' => 'true' },
      )

      expect(out).to eq('')
      expect(err).to match(/This script differs from the official version/)
      expect(status.exitstatus).to be 0
    end
  end # script out of sync with master

  context 'unknown error comparing source against master' do
    it 'prints a non-fatal warning' do
      stubbed_env.stub_command('diff').returns_exitstatus(2)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'CURL' => 'true' },
      )

      expect(out).to eq('')
      expect(err).to match(/There is an error in comparing/)
      expect(status.exitstatus).to be 0
    end
  end # unknown error comparing source against master
end
