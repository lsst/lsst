require 'rspec/bash'

describe 'n8l::eups_slug' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::eups_slug' }

  it 'prints $EUPS_VERSION' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
      { 'EUPS_VERSION' => 'banana' },
    )
    expect(status.exitstatus).to be 0
    expect(out).to match('banana')
    expect(err).to eq('')
  end

  it '$EUPS_GITREV overrides $EUPS_VERSION' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
      {
        'EUPS_VERSION' => 'banana',
        'EUPS_GITREV'  => 'apple',
      },
    )
    expect(status.exitstatus).to be 0
    expect(out).to match('apple')
    expect(err).to eq('')
  end
end
