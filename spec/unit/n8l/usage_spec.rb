require 'rspec/bash'

describe 'n8l::usage' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::usage' }

  it 'prints usage and dies' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )
    expect(out).to eq('')
    expect(err).to match(/usage: newinstall.sh/)
    expect(status.exitstatus).to_not be 0
  end
end
