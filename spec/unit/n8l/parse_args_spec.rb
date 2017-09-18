require 'rspec/bash'

describe 'n8l::parse_args' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }

  context 'cli options' do
    context 'without arguments' do
      %w[b c n 2 3 t T s S].each do |flag|
        context "-#{flag}" do
          it 'should not die' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "n8l::parse_args -#{flag}",
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
              "n8l::parse_args -#{flag} foo",
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
              "n8l::parse_args -#{flag}",
            )

            expect(out).to eq('')
            expect(err).to match(/usage: newinstall.sh/)

            expect(status.exitstatus).to_not be 0
          end
        end # context "-#{flag}"
      end
    end # context '-h or unknown option'
  end # context 'cli options'
end
