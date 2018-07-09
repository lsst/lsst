# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::config_curl' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::config_curl' }

  it 'sets $CURL & $CURL_OPTS' do
    script = <<-SCRIPT
      #{func}
      echo CURL=$CURL
      echo CURL_OPTS=$CURL_OPTS
    SCRIPT

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      script,
      { 'CURL' => '/dne/curl' }
    )

    expect(out).to match('CURL=/dne/curl')
    expect(out).to match(/(CURL_OPTS=-sS)|(-#)/)
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end
end
