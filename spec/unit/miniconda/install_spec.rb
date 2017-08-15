require 'rspec/bash'

describe 'miniconda::install' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }

  context 'parameters' do
    context '$1/py_ver' do
      it 'is required' do
        _, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'miniconda::install',
        )

        expect(status.exitstatus).to_not be 0
        expect(err).to match(/python version is required/)
      end
    end

    context '$2/mini_ver' do
      it 'is required' do
        _, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'miniconda::install foo',
        )

        expect(status.exitstatus).to_not be 0
        expect(err).to match(/miniconda version is required/)
      end
    end

    context '$3/prefix' do
      it 'is required' do
        _, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'miniconda::install foo bar',
        )

        expect(status.exitstatus).to_not be 0
        expect(err).to match(/prefix is required/)
      end
    end

    context '$4/miniconda_base_url' do
      it 'is optional' do
        curl = stubbed_env.stub_command('curl')

        _, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'CURL="curl"; miniconda::install foo bar baz',
        )

        expect(status.exitstatus).to be 0
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          %r|https://repo.continuum.io/miniconda|,
          '--output',
          instance_of(String)
        )
      end

      it 'https://example.org' do
        curl = stubbed_env.stub_command('curl')

        _, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'CURL="curl"; miniconda::install foo bar baz https://example.org',
        )

        expect(status.exitstatus).to be 0
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          %r|https://example.org|,
          '--output',
          instance_of(String)
        )
      end
    end
  end

  context 'uname' do
    {
      'Linux': 'Linux-x86_64',
      'Darwin': 'MacOSX-x86_64',
    }.each do |k,v|
      it k do
        installer = "Minicondafoo-bar-#{v}.sh"

        stubbed_env.stub_command('uname').outputs(k)
        stubbed_env.stub_command('mktmp')
        curl = stubbed_env.stub_command('curl')
        stubbed_env.stub_command('bash')

        out, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'CURL="curl"; miniconda::install foo bar baz',
        )

        expect(status.exitstatus).to be 0
        expect(curl).to be_called_with_arguments.times(1)
        expect(curl).to be_called_with_arguments(
          '', # empty $CURL_OPTS
          '-L',
          /#{installer}/,
          '--output',
          instance_of(String)
        )
        expect(out).to match(/#{installer}/)
      end
    end

    it '(unknown)' do
      stubbed_env.stub_command('uname').outputs('Batman-x86_64')

      _, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        'miniconda::install foo bar baz',
      )

      expect(status.exitstatus).to_not be 0
      expect(err).to match(/Cannot install miniconda: unsupported platform Batman-x86_64/)
    end
  end

  context 'mktemp template mangling' do
    %w[
      X
      XX
      XXX
      XXXX
    ].each do |pattern|
      it "removes #{pattern}" do
        installer = "Minicondafoo-#{pattern.gsub('X', '_')}-Linux-x86_64.sh"

        stubbed_env.stub_command('uname').outputs('Linux')
        mktemp = stubbed_env.stub_command('mktemp')
        stubbed_env.stub_command('curl')
        stubbed_env.stub_command('bash')

        _, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "CURL=\"curl\"; miniconda::install foo #{pattern} baz",
        )

        expect(status.exitstatus).to be 0
        expect(mktemp).to be_called_with_arguments.times(1)
        expect(mktemp).to be_called_with_arguments(
          '-t',
          "XXXXXXXX.#{installer}",
        )
      end
    end
  end
end
