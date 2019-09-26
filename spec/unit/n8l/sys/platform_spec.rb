# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::sys::platform' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::sys::platform' }

  context 'parameters' do
    context '$1/__osfamily' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/osfamily is required/)
      end
    end

    context '$2/__release' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/release is required/)
      end
    end

    context '$3/__platform_result' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/platform result variable is required/)
      end
    end

    context '$4/____target_cc_result' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} foo bar baz",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/target_cc result variable is required/)
      end
    end

    context '$5/__debug' do
      context 'is optional' do
        it 'without' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} foo bar baz quix",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq('')
          expect(err).to eq('')
        end

        it 'with' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} foo bar baz quix true",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq('')
          expect(err).to match(/unsupported osfamily: foo/)
        end
      end
    end
  end # parameters

  context 'osfamily' do
    context 'redhat' do
      context '6' do
        it 'computes' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            <<-SCRIPT
              #{func} redhat 6 baz quix
              echo PLATFORM=$baz
              echo TARGET_CC=$quix
            SCRIPT
          )

          expect(status.exitstatus).to be 0
          expect(out).to match(/PLATFORM=el6/)
          expect(out).to match(/TARGET_CC=devtoolset-8/)
          expect(err).to eq('')
        end
      end

      context '7' do
        it 'computes' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            <<-SCRIPT
              #{func} redhat 7 baz quix
              echo PLATFORM=$baz
              echo TARGET_CC=$quix
            SCRIPT
          )

          expect(status.exitstatus).to be 0
          expect(out).to match(/PLATFORM=el7/)
          expect(out).to match(/TARGET_CC=devtoolset-8/)
          expect(err).to eq('')
        end
      end
    end

    context 'osx' do
      %w[10.9.0 10.10.0 10.11.0].each do |ver|
        context ver do
          it 'computes' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              <<-SCRIPT
                #{func} osx #{ver} baz quix
                echo PLATFORM=$baz
                echo TARGET_CC=$quix
              SCRIPT
            )

            expect(status.exitstatus).to be 0
            expect(out).to match(/PLATFORM=10.9/)
            expect(out).to match(/TARGET_CC=clang-1000.10.44.4/)
            expect(err).to eq('')
          end
        end
      end
    end

    context 'foo' do
      it 'fails' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          <<-SCRIPT
            #{func} foo bar baz quix
            echo PLATFORM=$baz
            echo TARGET_CC=$quix
          SCRIPT
        )

        expect(status.exitstatus).to be 0
        expect(out).to match(/PLATFORM=$/)
        expect(out).to match(/TARGET_CC=$/)
        expect(err).to eq('')
      end
    end
  end # osfamily
end
