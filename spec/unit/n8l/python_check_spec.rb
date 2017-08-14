require 'rspec/bash'

describe 'n8l::python_check' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }

  context 'python interp' do
    it 'does not exist' do
      has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(1)

      out, _, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        'n8l::python_check',
      )

      expect(has_cmd).to be_called_with_arguments('python').times(1)
      expect(out).to match(/Unable to locate python./m)

      expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.5\)/m)

      # XXX function dies upon read -- can't figure out how to mock stdin or
      # shell builtins
      expect(status.exitstatus).to_not be 0
    end

    context 'got one' do
      it 'version OK' do
        has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)
        pyverok = stubbed_env.stub_command('n8l::pyverok').returns_exitstatus(0)

        out, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'n8l::python_check',
        )

        expect(has_cmd).to be_called_with_arguments('python').times(1)
        expect(pyverok).to be_called_with_arguments('python', '7', '5').times(1)
        expect(out).to_not match(/Unable to locate python./m)
        expect(out).to_not match(/LSST stack requires Python./m)

        expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.5\)/m)

        expect(status.exitstatus).to_not be 0
      end

      it 'version BAD' do
        has_cmd = stubbed_env.stub_command('n8l::has_cmd').returns_exitstatus(0)
        pyverok = stubbed_env.stub_command('n8l::pyverok').returns_exitstatus(1)

        out, _, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          'n8l::python_check',
        )

        expect(has_cmd).to be_called_with_arguments('python').times(1)
        expect(pyverok).to be_called_with_arguments('python', '7', '5').times(1)
        expect(out).to_not match(/Unable to locate python./m)
        expect(out).to match(/LSST stack requires Python./m)

        expect(out).to match(/Python 2 \(>=2.7\) or 3 \(>=3.5\)/m)

        expect(status.exitstatus).to_not be 0
      end
    end
  end
end
