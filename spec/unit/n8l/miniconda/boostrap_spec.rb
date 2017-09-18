require 'rspec/bash'

describe 'n8l::miniconda::bootstrap' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::bootstrap' }

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
        # LSST_HOME must be set after newinstall.sh is sourced to override it
        "LSST_HOME=/dne/home #{func}",
        {
          'LSST_PYTHON_VERSION' => '42',
          'MINICONDA_VERSION'   => 'apple',
          'MINICONDA_BASE_URL'  => 'https://example.org',
          'LSSTSW_REF'          => 'grape',
        },
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
        # LSST_HOME must be set after newinstall.sh is sourced to override it
        "LSST_HOME=/dne/home #{func}",
        {
          'LSST_PYTHON_VERSION' => '42',
          'MINICONDA_VERSION'   => 'apple',
          'MINICONDA_BASE_URL'  => 'https://example.org',
          'LSSTSW_REF'          => 'grape',
          'CONDA_CHANNELS'      => 'foo bar baz',
        },
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
