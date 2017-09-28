require 'rspec/bash'

describe 'n8l::fail' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::fail' }

  it 'dies' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )

    expect(status.exitstatus).to_not be 0
    expect(out).to eq('')
    expect(err).to eq('')
  end

  it 'dies and prints to stderr' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} \"lp is on fire!\"",
    )

    expect(status.exitstatus).to_not be 0
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end

  it 'dies with specified status and prints to stderr' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} \"lp is on fire!\" 42",
    )

    expect(status.exitstatus).to be 42
    expect(out).to eq('')
    expect(err).to match('lp is on fire!')
  end
end
