# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::parse_args' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::parse_args' }

  context 'cli options' do
    context 'without arguments' do
      %w[b c n 3 t T s S p].each do |flag|
        context "-#{flag}" do
          it 'should not die' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} -#{flag}",
            )

            expect(out).to eq('')
            expect(err).to eq('')
            expect(status.exitstatus).to be 0
          end
        end # context "-#{flag}"
      end
    end # context 'without arguments'

    context 'with arguments' do
      %w[P].each do |flag|
        context "-#{flag}" do
          it 'should not die' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} -#{flag} foo",
            )

            expect(out).to eq('')
            expect(err).to eq('')
            expect(status.exitstatus).to be 0
          end
        end # context "-#{flag}"
      end
    end # context 'with arguments'

    context '-h or unknown option' do
      %w[h z].each do |flag|
        context "-#{flag}" do
          it 'should die' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} -#{flag}",
            )

            expect(out).to eq('')
            expect(err).to match(/usage: newinstall.sh/)
            expect(status.exitstatus).to_not be 0
          end
        end # context "-#{flag}"
      end
    end # context '-h or unknown option'

    context '-p' do
      context 'unset' do
        it 'should not set PRESERVE_EUPS_PKGROOT_FLAG' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            <<-SCRIPT
              #{func}
              echo -n PRESERVE_EUPS_PKGROOT_FLAG=$PRESERVE_EUPS_PKGROOT_FLAG
            SCRIPT
          )

          expect(out).to eq('PRESERVE_EUPS_PKGROOT_FLAG=')
          expect(err).to eq('')
          expect(status.exitstatus).to be 0
        end
      end

      context 'set' do
        it 'should set PRESERVE_EUPS_PKGROOT_FLAG=true' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            <<-SCRIPT
              #{func} -p
              echo -n PRESERVE_EUPS_PKGROOT_FLAG=$PRESERVE_EUPS_PKGROOT_FLAG
            SCRIPT
          )

          expect(out).to eq('PRESERVE_EUPS_PKGROOT_FLAG=true')
          expect(err).to eq('')
          expect(status.exitstatus).to be 0
        end
      end
    end # context "-p"
  end # context 'cli options'

  context '-2' do
    it 'should die' do
      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} -2",
      )

      expect(out).to eq('')
      expect(err).to match(/Python 2.x is no longer supported./)
      expect(status.exitstatus).to_not be 0
    end
  end # context -2
end
