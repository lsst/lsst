require 'rspec/bash'

describe 'n8l::sys::osfamily' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::sys::osfamily' }

  context 'parameters' do
    context '$1/__osfamily_result' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/osfamily result variable is required/)
      end
    end

    context '$2/__release_result=' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/release result variable is required/)
      end
    end

    context '$3/__debug' do
      context 'is optional' do
        it 'without' do
          stubbed_env.stub_command('uname').outputs('foo')

          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} foo bar",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq('')
          expect(err).to eq('')
        end

        it 'with' do
          stubbed_env.stub_command('uname').outputs('foo')

          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} foo bar true",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq('')
          expect(err).to match(/unknown osfamily/)
        end
      end
    end
  end # parameters

  context 'uname' do
    context 'Linux' do
      it 'probes' do
        pending('figuring out how to stub reads from filesystem')
        raise 'TODO'
      end
    end

    context 'Darwin' do
      it 'probes' do
        stubbed_env.stub_command('uname').outputs('Darwin')
        stubbed_env.stub_command('sw_vers').outputs('42')

        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          <<-SCRIPT
            #{func} foo bar
            echo OSFAMILY=$foo
            echo RELEASE=$bar
          SCRIPT
        )

        expect(status.exitstatus).to be 0
        expect(out).to match(/OSFAMILY=osx/)
        expect(out).to match(/RELEASE=42/)
        expect(err).to eq('')
      end
    end
  end # uname
end
