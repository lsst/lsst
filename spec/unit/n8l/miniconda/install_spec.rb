# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::miniconda::install' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::install' }

  context 'parameters' do
    context '$1/mini_ver' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} ",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/miniconda version is required/)
      end
    end

    context '$2/prefix' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/prefix is required/)
      end
    end

    context '$3/miniconda_base_url' do
      it 'is optional' do
        stubbed_env.stub_command('uname').outputs('Linux')
        curl = stubbed_env.stub_command('curl')
        bash = stubbed_env.stub_command('bash')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar",
          { 'CURL' => 'curl' },
        )

        expect(status.exitstatus).to be 0
        expect(out).to match(/Deploying Miniconda3-latest-Linux-x86_64.sh/)
        expect(err).to eq('')

        expect(curl).to be_called_with_arguments.times(1)
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          %r{https://repo.continuum.io/miniconda},
          '--output',
          instance_of(String)
        )
        expect(bash).to be_called_with_arguments.times(1)
        expect(bash).to be_called_with_arguments(
          %r{Miniconda3-latest-Linux-x86_64.sh},
          '-b',
          '-p',
          instance_of(String)
        )
      end

      it 'https://example.org' do
        stubbed_env.stub_command('uname').outputs('Linux')
        curl = stubbed_env.stub_command('curl')
        bash = stubbed_env.stub_command('bash')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar https://example.org",
          { 'CURL' => 'curl' },
        )

        expect(status.exitstatus).to be 0
        expect(out).to match(/Deploying Miniconda3-latest-Linux-x86_64.sh/)
        expect(err).to eq('')

        expect(curl).to be_called_with_arguments.times(1)
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          %r{https://example.org},
          '--output',
          instance_of(String)
        )
        expect(bash).to be_called_with_arguments(
          %r{Miniconda3-latest-Linux-x86_64.sh},
          '-b',
          '-p',
          instance_of(String)
        )
      end
    end
  end

  context 'uname' do
    {
      'Linux': 'Linux-x86_64',
      'Darwin': 'MacOSX-x86_64',
    }.each do |k, v|
      it k do
        installer = "Miniconda3-latest-#{v}.sh"

        stubbed_env.stub_command('uname').outputs(k)
        stubbed_env.stub_command('mktemp')
        curl = stubbed_env.stub_command('curl')
        stubbed_env.stub_command('bash')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz",
          { 'CURL' => 'curl' },
        )

        expect(status.exitstatus).to be 0
        expect(out).to match(/#{installer}/)
        expect(err).to eq('')

        expect(curl).to be_called_with_arguments.times(1)
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          /#{installer}/,
          '--output',
          instance_of(String)
        )
      end
    end

    it '(unknown)' do
      stubbed_env.stub_command('uname').outputs('Batman-x86_64')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} foo bar",
      )

      expect(status.exitstatus).to_not be 0
      expect(out).to eq('')
      expect(err).to match(
        'Cannot install miniconda: unsupported platform Batman-x86_64'
      )
    end
  end
end
