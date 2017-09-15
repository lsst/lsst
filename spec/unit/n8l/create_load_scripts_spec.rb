require 'rspec/bash'

describe 'n8l::create_load_scripts' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::create_load_scripts' }

  let(:shells) { %w[bash csh ksh zsh] }

  it 'works' do
    cmds = Hash[shells.collect do |sh|
                  [
                    sh,
                    stubbed_env.stub_command("n8l::generate_loader_#{sh}")
                  ]
                end
           ]

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "LSST_HOME=/dne #{func}",
    )

    expect(status.exitstatus).to be 0
    shells.each { |sh| expect(out).to match(sh) }
    expect(err).to eq('')

    cmds.each do |sh, stub|
      expect(stub).to be_called_with_arguments.times(1)
      expect(stub).to be_called_with_arguments("/dne/loadLSST.#{sh}")
    end
  end
end
