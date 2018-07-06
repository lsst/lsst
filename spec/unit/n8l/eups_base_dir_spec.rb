require 'rspec/bash'

describe 'n8l::eups_base_dir' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::eups_base_dir' }

  it 'prints path' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      # LSST_HOME should be set after script is sourced
      "LSST_HOME=/dne/home #{func}",
    )
    expect(out).to match('/dne/home/eups')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
