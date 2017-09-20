require 'rspec/bash'

describe 'n8l::create_load_scripts' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::create_load_scripts' }

  let(:shells) { %w[bash csh ksh zsh] }
  before(:example) do
    @cmds = Hash[shells.collect do |sh|
                   [
                     sh,
                     stubbed_env.stub_command("n8l::generate_loader_#{sh}")
                   ]
                 end
            ]
  end

  context 'parameters' do
    context '$1/prefix' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(out).to eq('')
        expect(err).to match(/prefix is required/)
        expect(status.exitstatus).to_not be 0
      end
    end

    context '$2/miniconda_path' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(out).to eq('')
        expect(err).to match(/miniconda_path is required/)
        expect(status.exitstatus).to_not be 0
      end
    end
  end

  it 'works' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} /dne /dne/python/banana",
    )

    shells.each { |sh| expect(out).to match(/#{sh}/) }
    expect(err).to eq('')
    expect(status.exitstatus).to be 0

    @cmds.each do |sh, stub|
      expect(stub).to be_called_with_arguments.times(1)
      expect(stub).to be_called_with_arguments(
        "/dne/loadLSST.#{sh}",
        '/dne/python/banana',
      )
    end
  end
end
