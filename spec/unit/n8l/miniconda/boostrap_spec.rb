# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::miniconda::bootstrap' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::bootstrap' }

  let(:stubbed_cmds) do
    %w[
      rm
      n8l::miniconda::install
      n8l::ln_rel
      n8l::miniconda::lsst_env
      conda
      source
    ]
  end

  context 'parameters' do
    before(:each) do
      @cmds = Hash[stubbed_cmds.collect do |c|
                     [c, stubbed_env.stub_command(c)]
                   end
              ]
    end

    context '$1/miniconda_path' do
      it 'can be empty' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} '' bar baz qux blep",
        )

        expect(out).to match(/Installing conda at baz\/conda\/miniconda/)
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep blah",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end
    end

    context '$2/mini_ver' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(out).to eq('')
        expect(err).to match(/miniconda version is required/)
        expect(status.exitstatus).to_not be 0
      end
    end

    context '$3/prefix' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar",
        )

        expect(out).to eq('')
        expect(err).to match(/prefix is required/)
        expect(status.exitstatus).to_not be 0
      end
    end

    context '$4/__miniconda_path_result' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz",
        )

        expect(out).to eq('')
        expect(err).to match(/__miniconda_path_result is required/)
        expect(status.exitstatus).to_not be 0
      end
    end

    context '$5/miniconda_base_url' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end
    end

    context '$6/lsstsw_ref' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep blah",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end
    end

    context '$7/conda_channels' do
      it 'is optional' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep blah",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end

      it 'is accepted' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz qux blep blah boop",
        )

        expect(out).to eq("Using conda at foo\n")
        expect(err).to match('')
        expect(status.exitstatus).to be 0
      end
    end
  end

  context 'without $lsstsw_ref' do
    it 'works' do
      miniconda_slug = stubbed_env.stub_command('n8l::miniconda_slug')
                                  .outputs('banana')
      install = stubbed_env.stub_command('n8l::miniconda::install')
      ln_rel = stubbed_env.stub_command('n8l::ln_rel')
      source = stubbed_env.stub_command('source')
      conda = stubbed_env.stub_command('conda')
      lsst_env = stubbed_env.stub_command('n8l::miniconda::lsst_env')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          #{func} '' apple /dne/home MINI_PATH https://example.org
        SCRIPT
      )

      expect(out).to match(%r{Installing conda at /dne/home/conda/banana})
      expect(err).to eq('')
      expect(status.exitstatus).to be 0

      # sadly, be_called_with_no_arguments() does not support times()
      expect(miniconda_slug).to be_called_with_no_arguments
      expect(install).to be_called_with_arguments.times(1)
      expect(install).to be_called_with_arguments(
        'apple',
        '/dne/home/conda/banana',
        'https://example.org',
      )
      expect(ln_rel).to be_called_with_arguments.times(1)
      expect(ln_rel).to be_called_with_arguments(
        '/dne/home/conda/banana',
        'current',
      )

      expect(source).to be_called_with_arguments.times(1)
      expect(source).to be_called_with_arguments(
        '/dne/home/conda/banana/bin/activate',
      )

      expect(conda).to be_called_with_arguments.times(1)
      expect(conda).to be_called_with_arguments('deactivate')

      # not called unless lsstsw_ref is defined
      expect(lsst_env).to_not be_called
    end
  end # without $lsstsw_ref

  context 'without $conda_channels' do
    it 'works' do
      miniconda_slug = stubbed_env.stub_command('n8l::miniconda_slug')
                                  .outputs('banana')
      install = stubbed_env.stub_command('n8l::miniconda::install')
      ln_rel = stubbed_env.stub_command('n8l::ln_rel')
      source = stubbed_env.stub_command('source')
      conda = stubbed_env.stub_command('conda')
      lsst_env = stubbed_env.stub_command('n8l::miniconda::lsst_env')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          #{func} '' apple /dne/home MINI_PATH https://example.org grape
        SCRIPT
      )

      expect(out).to match(%r{Installing conda at /dne/home/conda/banana})
      expect(err).to eq('')
      expect(status.exitstatus).to be 0

      # sadly, be_called_with_no_arguments() does not support times()
      expect(miniconda_slug).to be_called_with_no_arguments
      expect(install).to be_called_with_arguments.times(1)
      expect(install).to be_called_with_arguments(
        'apple',
        '/dne/home/conda/banana',
        'https://example.org',
      )
      expect(ln_rel).to be_called_with_arguments.times(1)
      expect(ln_rel).to be_called_with_arguments(
        '/dne/home/conda/banana',
        'current',
      )

      expect(source).to be_called_with_arguments.times(1)
      expect(source).to be_called_with_arguments(
        '/dne/home/conda/banana/bin/activate',
      )

      expect(conda).to be_called_with_arguments.times(1)
      expect(conda).to be_called_with_arguments(
        'deactivate',
      )

      # not called unless lsstsw_ref is defined
      expect(lsst_env).to be_called_with_arguments.times(1)
      expect(lsst_env).to be_called_with_arguments(
        'grape',
        '/dne/home/conda/banana',
        '',
      )
    end
  end # without $conda_channels

  context 'all parameters' do
    it 'works' do
      source = stubbed_env.stub_command('source')
      conda = stubbed_env.stub_command('conda')
      lsst_env = stubbed_env.stub_command('n8l::miniconda::lsst_env')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        <<-SCRIPT
          #{func} \
            'mockpath' \
            apple \
            /dne/home \
            MINI_PATH \
            https://example.org \
            grape \
            "foo bar baz"
        SCRIPT
      )

      expect(out).to eq("Using conda at mockpath\n")
      expect(err).to eq('')
      expect(status.exitstatus).to be 0

      # We do NOT install conda in this case
      expect(source).to be_called_with_arguments.times(1)
      expect(source).to be_called_with_arguments(
        'mockpath/bin/activate',
      )

      expect(lsst_env).to be_called_with_arguments.times(1)
      expect(lsst_env).to be_called_with_arguments(
        'grape',
        'mockpath',
        'foo bar baz'
      )

      # expect(config_channels).to be_called_with_arguments.times(1)
      # expect(config_channels).to be_called_with_arguments('foo bar baz')

      expect(conda).to be_called_with_arguments.times(1)
      expect(conda).to be_called_with_arguments(
        'deactivate',
      )
    end
  end # with $conda_channels
end
