require 'rspec/bash'

describe 'n8l::miniconda::bootstrap' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::bootstrap' }

  context 'parameters' do
		before(:each) do
			%w[
				rm
				n8l::miniconda::install
				n8l::ln_rel
				n8l::miniconda::config_channels
				n8l::miniconda::lsst_env
			].each { |cmd| stubbed_env.stub_command(cmd) }
		end

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

    context '$2/mini_ver' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/miniconda version is required/)
      end
    end

    context '$3/prefix' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/prefix is required/)
      end
    end

    context '$4/miniconda_base_url' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end
    end

    context '$5/lsstsw_ref' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blah",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end
    end

    context '$6/conda_channels' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blah",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blah boop",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')
      end
    end
  end

  context 'without $CONDA_CHANNELS' do
    it 'works' do
      miniconda_slug = stubbed_env.stub_command('n8l::miniconda_slug')
                                  .outputs('banana')
      install = stubbed_env.stub_command('n8l::miniconda::install')
      ln_rel = stubbed_env.stub_command('n8l::ln_rel')
      config_channels = stubbed_env.stub_command(
        'n8l::miniconda::config_channels'
      )
      lsst_env = stubbed_env.stub_command('n8l::miniconda::lsst_env')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} 42 apple /dne/home https://example.org grape",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')

      # sadly, be_called_with_no_arguments() does not support times()
      expect(miniconda_slug).to be_called_with_no_arguments
      expect(install).to be_called_with_arguments.times(1)
      expect(install).to be_called_with_arguments(
        '42',
        'apple',
        '/dne/home/python/banana',
        'https://example.org',
      )
      expect(ln_rel).to be_called_with_arguments.times(1)
      expect(ln_rel).to be_called_with_arguments(
        '/dne/home/python/banana',
        'current',
      )
      # not called unless CONDA_CHANNELS is defined
      expect(config_channels).to_not be_called
      expect(lsst_env).to be_called_with_arguments.times(1)
      expect(lsst_env).to be_called_with_arguments(
        '42',
        'grape',
      )
    end
  end # without $CONDA_CHANNELS

  context 'with $CONDA_CHANNELS' do
    it 'works' do
      miniconda_slug = stubbed_env.stub_command('n8l::miniconda_slug')
                                  .outputs('banana')
      install = stubbed_env.stub_command('n8l::miniconda::install')
      ln_rel = stubbed_env.stub_command('n8l::ln_rel')
      config_channels = stubbed_env.stub_command(
        'n8l::miniconda::config_channels'
      )
      lsst_env = stubbed_env.stub_command('n8l::miniconda::lsst_env')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} 42 apple /dne/home https://example.org grape \"foo bar baz\"",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')

      # sadly, be_called_with_no_arguments() does not support times()
      expect(miniconda_slug).to be_called_with_no_arguments
      expect(install).to be_called_with_arguments.times(1)
      expect(install).to be_called_with_arguments(
        '42',
        'apple',
        '/dne/home/python/banana',
        'https://example.org',
      )
      expect(ln_rel).to be_called_with_arguments.times(1)
      expect(ln_rel).to be_called_with_arguments(
        '/dne/home/python/banana',
        'current',
      )
      expect(config_channels).to be_called_with_arguments.times(1)
      expect(config_channels).to be_called_with_arguments('foo bar baz')
      expect(lsst_env).to be_called_with_arguments.times(1)
      expect(lsst_env).to be_called_with_arguments(
        '42',
        'grape',
      )
    end
  end # with $CONDA_CHANNELS
end
