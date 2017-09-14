require 'rspec/bash'

describe 'n8l::pyverok' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::pyverok' }

  context 'parameters' do
    it '(defaults)' do
      py = stubbed_env.stub_command('python')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func}",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')

      expect(py).to be_called_with_arguments.times(1)
      expect(py).to be_called_with_arguments('-c', /minver2=7/)
      expect(py).to be_called_with_arguments('-c', /minver3=5/)
    end

    it '3 params' do
      py = stubbed_env.stub_command('batman')

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} batman 12 34",
      )

      expect(status.exitstatus).to be 0
      expect(out).to eq('')
      expect(err).to eq('')

      expect(py).to be_called_with_arguments.times(1)
      expect(py).to be_called_with_arguments('-c', /minver2=12/)
      expect(py).to be_called_with_arguments('-c', /minver3=34/)
    end
  end

  context 'python fails' do
    it 'returns python exitstatus' do
      stubbed_env.stub_command('python').returns_exitstatus(1)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func}",
      )

      expect(status.exitstatus).to be 1
      expect(out).to eq('')
      expect(err).to eq('')
    end
  end
end
