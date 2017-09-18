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
        'LSST_PYTHON_VERSION' => '800',
        'MINICONDA_VERSION'   => 'banana',
      },
    )
    expect(status.exitstatus).to be 0
    expect(out).to match('miniconda800-banana')
    expect(err).to eq('')
  end
end
