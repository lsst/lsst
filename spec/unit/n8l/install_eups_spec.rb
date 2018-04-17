require 'rspec/bash'

describe 'n8l::install_eups' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::install_eups' }

  context '$EUPS_PYTHON not set to executable' do
    it 'should die' do
      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "EUPS_PYTHON=/dne/foo/bar #{func}",
      )

      expect(status.exitstatus).to_not be 0
      expect(out).to eq('')
      expect(err).to match("Cannot find or execute '/dne/foo/bar'.")
    end
  end

  # the travis env does not include /usr/bin/true...
  if File.exist?('/usr/bin/true')
    context 'python below minimum version' do
      it 'should die' do
        stubbed_env.stub_command('git')
        stubbed_env.stub_command('n8l::pyverok').returns_exitstatus(1)

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          # assuming that /usr/bin/true will always be a real executable on the
          # test system as `-x` can not be mocked out.
          "EUPS_PYTHON=/usr/bin/true #{func}",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match('EUPS requires Python 2.6 or newer')
      end
    end
  end

  # XXX unable to test postive examples as rspec-bash is unable to mock out a
  # fully qualified command path.  This is needed to shadow a real binary (eg.,
  # /usr/bin/true) in order to get past the initial `-x` test.
end
