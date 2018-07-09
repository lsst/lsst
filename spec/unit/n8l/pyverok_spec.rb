# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::pyverok' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::pyverok' }

  context 'parameters' do
    context '$1/min_major' do
      it 'is required' do
        py = stubbed_env.stub_command('python').returns_exitstatus(0)
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(out).to eq('')
        expect(err).to match('min_major is required')
        expect(status.exitstatus).to_not be 0

        expect(py).to_not be_called_with_arguments
      end
    end

    context '$2/min_minor' do
      it 'is required' do
        py = stubbed_env.stub_command('python').returns_exitstatus(0)
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} 42",
        )

        expect(out).to eq('')
        expect(err).to match('min_minor is required')
        expect(status.exitstatus).to_not be 0

        expect(py).to_not be_called_with_arguments
      end
    end

    context '$3/py_interp' do
      context 'is optional' do
        it 'without' do
          py = stubbed_env.stub_command('python').returns_exitstatus(0)
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} 42 7",
          )

          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to be 0

          expect(py).to be_called_with_arguments.times(1)
        end

        it 'with' do
          py  = stubbed_env.stub_command('python').returns_exitstatus(1)
          foo = stubbed_env.stub_command('foo').returns_exitstatus(0)

          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "#{func} 42 7 foo",
          )

          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to be 0

          expect(py).to_not be_called_with_arguments

          expect(foo).to be_called_with_arguments.times(1)
          expect(foo).to be_called_with_arguments('-c', /rmaj=42/)
          expect(foo).to be_called_with_arguments('-c', /rmin=7/)
        end
      end # is optional
    end # $3/py_interp
  end # parameters

  context 'python fails' do
    it 'returns python exitstatus' do
      py = stubbed_env.stub_command('python').returns_exitstatus(1)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} 42 7",
      )

      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to be 1

      expect(py).to be_called_with_arguments.times(1)
    end
  end
end
