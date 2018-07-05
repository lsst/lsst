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
          Linux: "conda#{pyver}_packages-linux-64.txt",
          Darwin: "conda#{pyver}_packages-osx-64.txt",
        }.each do |uname, envfile|
          it uname do
            stubbed_env.stub_command('uname').outputs(uname)
            stubbed_env.stub_command('mktemp').outputs('/dne/file')
            curl = stubbed_env.stub_command('curl')
            conda = stubbed_env.stub_command('conda')

            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} #{pyver} foo",
              { 'CURL' => 'curl' },
            )

            expect(status.exitstatus).to be 0
            expect(out).to eq('')
            expect(err).to eq('')

            expect(curl).to be_called_with_arguments.times(1)
            expect(curl).to be_called_with_arguments(
              '', # empty $CURL_OPTS
              '-L',
              /#{envfile}/,
              '--output',
              instance_of(String)
            )

            expect(conda).to be_called_with_arguments.times(3)
            expect(conda).to be_called_with_arguments('clean', '--lock')
            expect(conda).to be_called_with_arguments(
              'env',
              'update',
              '--name',
              /^lsst-scipipe/,
              '--quiet',
              '--file',
              '/dne/file',
            )
          end
        end
      end
    end

    it '(unknown)' do
      stubbed_env.stub_command('uname').outputs('foo')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} foo bar",
      )

      expect(status.exitstatus).to_not be 0
      expect(out).to eq('')
      expect(err).to match(
        'Cannot configure miniconda env: unsupported platform foo'
      )
    end
  end # uname
end
