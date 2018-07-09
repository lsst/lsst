# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::miniconda::config_channels' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::miniconda::config_channels' }

  context 'parameters' do
    context '$1/channels' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/channels is required/)
      end

      it 'adds multiple channels' do
        conda = stubbed_env.stub_command('conda')
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} \"a b c\"",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')

        %w[a b c].each do |chan|
          expect(conda).to be_called_with_arguments(
            'config', '--add', 'channels', chan
          )
        end
      end
    end
  end
end
