# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::trim' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::trim' }

  it 'does not change strings without spaces' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} foobarbaz",
    )

    expect(out).to match('foobarbaz')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  it 'trims string passed as one param' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} \"  foo  bar  baz  \"",
    )

    expect(out).to match('foo  bar  baz')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  it 'trims string(s) passed as multiple params' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} \"  foo \" \" bar \" \" baz  \"",
    )

    expect(out).to match('foo   bar   baz')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
