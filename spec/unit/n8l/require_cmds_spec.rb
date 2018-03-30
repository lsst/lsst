require 'rspec/bash'

describe 'n8l::require_cmds' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::require_cmds' }

  context 'parameters' do
    context '$1/command(s)' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/at least one command is required/)
      end

      it 'is passed to `command`' do
        haz_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')

        expect(haz_cmd).to be_called_with_arguments.times(1)
        expect(haz_cmd).to be_called_with_arguments('foo')
      end

      it 'multiple args are passed to `command`' do
        haz_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz",
        )

        expect(status.exitstatus).to be 0
        expect(out).to eq('')
        expect(err).to eq('')

        expect(haz_cmd).to be_called_with_arguments.times(3)
        %w[foo bar baz].each do |cmd|
          expect(haz_cmd).to be_called_with_arguments(cmd)
        end
      end

      it 'fails when `command` does not exist' do
        haz_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(1)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match('prog: foo is required')
        expect(haz_cmd).to be_called_with_arguments.times(1)
        expect(haz_cmd).to be_called_with_arguments('foo')
      end
    end
  end
end
