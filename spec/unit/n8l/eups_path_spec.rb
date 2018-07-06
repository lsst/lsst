require 'rspec/bash'

describe 'n8l::eups_path' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::eups_path' }

  it 'prints path' do
    stubbed_env.stub_command('n8l::python_env_slug').outputs('banana')

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "LSST_HOME=/dne/home #{func}",
    )
    expect(out).to match('/dne/home/stack/banana')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
