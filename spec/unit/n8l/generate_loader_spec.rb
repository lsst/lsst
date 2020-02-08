# frozen_string_literal: true

require 'rspec/bash'
require 'tempfile'

describe 'n8l::generate_loader_*' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }

  # Unfortunately, this example(s) needs to write to the filesystem. While
  # `cat` can be mocked out, bash i/o redirection can not.
  %w[bash csh ksh zsh].each do |sh|
    func = "n8l::generate_loader_#{sh}"

    describe func do
      context 'parameters' do
        context '$1/file_name' do
          it 'is required' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              func,
            )

            expect(out).to eq('')
            expect(err).to match('file_name is required')
            expect(status.exitstatus).to_not be 0
          end
        end

        context '$2/eups_pkgroot' do
          it 'is required' do
            out, err, status = stubbed_env.execute_function(
              'scripts/newinstall.sh',
              "#{func} foo"
            )

            expect(out).to eq('')
            expect(err).to match('eups_pkgroot is required')
            expect(status.exitstatus).to_not be 0
          end
        end

        context '$3/miniconda_path' do
          %w[with without].each do |have|
            Tempfile.create(sh) do |f|
              context have do
                have == 'with' && miniconda_path = "#{f.path}/python/banana"

                it "writes loadLSST script #{have} PATH" do
                  out, err, status = stubbed_env.execute_function(
                    'scripts/newinstall.sh',
                    "#{func} #{f.path} /dne/banana #{miniconda_path}"
                  )

                  expect(out).to eq('')
                  expect(err).to eq('')
                  expect(status.exitstatus).to be 0

                  loader = File.read(f)

                  expect(loader).to match(
                    "This script is intended to be used with.*#{sh}"
                  )
                  expect(loader).to match('/dne/banana')
                end
              end
            end # $3/miniconda_path
          end # Tempfile
        end # have
      end # parameters
    end # func
  end # shell
end
