# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::miniconda::lsst_env' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::lsst_env' }

  context 'parameters' do
    context '$1/py_ver' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/python version is required/)
      end
    end

    context '$2/ref' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/lsstsw git ref is required/)
      end
    end
  end # parameters

  context 'uname' do
    %w[2 3].each do |pyver|
      context "py#{pyver}" do
        {
          Linux: "conda#{pyver}_packages-linux-64.yml",
          Darwin: "conda#{pyver}_packages-osx-64.yml",
        }.each do |uname, envfile|
          it uname do
            stubbed_env.stub_command('uname').outputs(uname)
            stubbed_env.stub_command('mktemp').outputs('/dne/file')
            curl = stubbed_env.stub_command('curl')
            conda = stubbed_env.stub_command('conda')
            source = stubbed_env.stub_command('source')
            # stubbed only to be found by n8l::require_cmd
            stubbed_env.stub_command('activate')

            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} #{pyver} foo",
              { 'CURL' => 'curl' },
            )

            expect(out).to eq('')
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

            expect(conda).to be_called_with_arguments.times(2)
            expect(conda).to be_called_with_arguments(
              'env',
              'update',
              '--name',
              /^lsst-scipipe/,
              '--quiet',
              '--file',
              '/dne/file.yml',
            )
            expect(conda).to be_called_with_arguments('env', 'export')

            expect(source).to be_called_with_arguments.times(1)
            expect(source).to be_called_with_arguments(
              'activate',
              /^lsst-scipipe-/,
            )
          end
        end
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
