require 'rspec/bash'

describe 'n8l::up2date_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::up2date_check' }

  context 'script matches master' do
    it 'prints nothing' do
      stubbed_env.stub_command('diff').outputs('notta')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'CURL' => 'true' },
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')
    end
  end # script matches master

  context 'script out of sync with master' do
    it 'prints a non-fatal warning' do
      stubbed_env.stub_command('diff').outputs('differ')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
        { 'CURL' => 'true' },
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to match(/This script differs from the official version/)
    end
  end # script matches master
end
