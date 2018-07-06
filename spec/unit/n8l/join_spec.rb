require 'rspec/bash'

describe 'n8l::join' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::join' }

  it 'dies with no params' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )

    expect(out).to eq('')
    expect(err).to match(/separator is required/)
    expect(status.exitstatus).to_not be 0
  end

  it 'separator param only is noop' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} '@'",
    )

    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  it 'separator param only is noop' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} '@' a b c d",
    )

    expect(out).to eq('a@b@c@d')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
