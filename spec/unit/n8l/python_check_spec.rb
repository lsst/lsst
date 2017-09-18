require 'rspec/bash'

describe 'n8l::python_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::python_check' }

  context 'python interp' do
    it 'does not exist' do
      has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(1)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
      )

      # XXX can't figure out how to mock `read` and have it set env vars
      expect(status.exitstatus).to_not be 0
      expect(out).to match(/Unable to locate python./m)
      expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.6\)/m)
      expect(err).to eq('')

      expect(has_cmd).to be_called_with_arguments('python').times(1)
    end

    context 'got one' do
      it 'version OK' do
        has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)
        pyverok = stubbed_env.stub_command('n8l::pyverok').returns_exitstatus(0)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.6\)/m)
        expect(err).to eq('')

        expect(out).to_not match(/Unable to locate python./m)
        expect(out).to_not match(/LSST stack requires Python./m)

        expect(has_cmd).to be_called_with_arguments('python').times(1)
        expect(pyverok).to be_called_with_arguments('python', '7', '6').times(1)
      end

      it 'version BAD' do
        has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)
        pyverok = stubbed_env.stub_command('n8l::pyverok').returns_exitstatus(1)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.6\)/m)
        expect(out).to match(/LSST stack requires Python./m)
        expect(err).to eq('')

        expect(out).to_not match(/Unable to locate python./m)

        expect(has_cmd).to be_called_with_arguments('python').times(1)
        expect(pyverok).to be_called_with_arguments('python', '7', '6').times(1)
      end
    end
  end
end
