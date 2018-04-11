require 'rspec/bash'

describe 'n8l::miniconda_slug' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda_slug' }

  it 'prints version slug' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
      {
        'MINICONDA_VERSION' => 'banana',
      },
    )
    expect(status.exitstatus).to be 0
    expect(out).to match('miniconda3-banana')
    expect(err).to eq('')
  end
end
