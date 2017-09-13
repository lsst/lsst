require 'rspec/bash'

describe 'n8l::print_error' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::print_error' }

  it 'prints to stderr' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      # this mysteriously breaks with single quotes...
      'n8l::print_error "lp is on fire!"',
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end

  it 'prints multiple params to stderr' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} 'lp' 'is' 'on' 'fire!'",
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end
end
