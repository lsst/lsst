require 'rspec/bash'

describe 'n8l::am_i_sourced' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::am_i_sourced' }

  context 'not being sourced' do
    it 'dies' do
      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        func,
      )

      expect(out).to eq('')
      expect(err).to eq('')
      expect(status.exitstatus).to_not be 0
    end
  end
end
