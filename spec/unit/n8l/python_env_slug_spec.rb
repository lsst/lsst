# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::python_env_slug' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::python_env_slug' }

  it 'prints version slug' do
    stubbed_env.stub_command('n8l::miniconda_slug').outputs('miniconda9-apple')

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
      { 'LSST_SPLENV_REF' => 'banana' },
    )
    expect(out).to match('miniconda9-apple-banana')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
