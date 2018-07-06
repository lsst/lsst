require 'rspec/bash'

describe 'n8l::print_greeting' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::print_greeting' }

  it 'prints a hallmark moment' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )

    expect(out).to match('Bootstrap complete.')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
