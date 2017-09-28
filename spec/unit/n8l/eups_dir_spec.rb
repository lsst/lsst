require 'rspec/bash'

describe 'n8l::eups_dir' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::eups_dir' }

  it 'prints path' do
    stubbed_env.stub_command('n8l::eups_base_dir').outputs('/dne/eups')
    stubbed_env.stub_command('n8l::eups_slug').outputs('banana')

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )
    expect(status.exitstatus).to be 0
    expect(out).to match('/dne/eups/banana')
    expect(err).to eq('')
  end
end
