# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::miniconda::lsst_env' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::lsst_env' }

  context 'parameters' do
    context '$1/ref' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/lsstsw git ref is required/)
      end
    end
  end # parameters

  context 'uname' do
    {
      Linux: 'conda-linux-64.lock',
      Darwin: 'conda-osx-64.lock',
    }.each do |uname, envfile|
      it uname do
        stubbed_env.stub_command('uname').outputs(uname)
        stubbed_env.stub_command('mktemp').outputs('/dne/file')
        curl = stubbed_env.stub_command('curl')
        conda = stubbed_env.stub_command('conda')
        config_channels = stubbed_env.stub_command(
          'n8l::miniconda::config_channels'
        )
        # stubbed only to be found by n8l::require_cmd
        stubbed_env.stub_command('activate')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} '' foo 'bar baz'",
          { 'CURL' => 'curl' },
        )

        # Notice that we cleaned the environment should be printed
        expect(out).to eq("Cleaning conda environment...\ndone\n")
        expect(err).to eq('')
        expect(status.exitstatus).to be 0

        expect(curl).to be_called_with_arguments.times(1)
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          /#{envfile}/,
          '--output',
          instance_of(String)
        )

        expect(conda).to be_called_with_arguments.times(5)
        expect(conda).to be_called_with_arguments(
          'create',
          '--name',
          /^lsst-scipipe/,
          '--quiet',
          '--file',
          '/dne/file.yml',
        )
        expect(conda).to be_called_with_arguments('clean', '-y', '-a')
        expect(conda).to be_called_with_arguments('activate', /^lsst-scipipe/)
        expect(conda).to be_called_with_arguments('env', 'export')

        expect(config_channels).to be_called_with_arguments.times(1)
        expect(config_channels).to be_called_with_arguments('bar baz')

        expect(conda).to be_called_with_arguments('deactivate')
      end
    end

    it '(unknown)' do
      stubbed_env.stub_command('uname').outputs('foo')
      # stubbed only to be found by n8l::require_cmd
      stubbed_env.stub_command('conda')
      stubbed_env.stub_command('activate')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} foo bar",
      )

      expect(out).to eq('')
      expect(err).to match(
        'Cannot configure miniconda env: unsupported platform foo'
      )
      expect(status.exitstatus).to_not be 0
    end
  end # uname
end
