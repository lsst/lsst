# frozen_string_literal: true

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

    context '$2/eups_pkgroot' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(out).to eq('')
        expect(err).to match('eups_pkgroot is required')
        expect(status.exitstatus).to_not be 0
      end
    end

    context '$3/miniconda_path' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar",
        )

        expect(out).to match('Creating startup scripts')
        expect(err).to eq('')
        expect(status.exitstatus).to be 0
      end
    end
  end

  it 'does not invent a miniconda_path' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} /dne /dne/apple",
    )

    shells.each { |sh| expect(out).to match(/#{sh}/) }
    expect(err).to eq('')
    expect(status.exitstatus).to be 0

    @cmds.each do |sh, stub|
      expect(stub).to be_called_with_arguments.times(1)
      expect(stub).to be_called_with_arguments(
        "/dne/loadLSST.#{sh}",
        '/dne/apple',
      )
    end
  end

  it 'passes through miniconda_path' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} /dne /dne/apple /dne/python/banana",
    )

    shells.each { |sh| expect(out).to match(/#{sh}/) }
    expect(err).to eq('')
    expect(status.exitstatus).to be 0

    @cmds.each do |sh, stub|
      expect(stub).to be_called_with_arguments.times(1)
      expect(stub).to be_called_with_arguments(
        "/dne/loadLSST.#{sh}",
        '/dne/apple',
        '/dne/python/banana',
      )
    end
  end
end
