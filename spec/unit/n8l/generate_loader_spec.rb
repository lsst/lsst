require 'rspec/bash'
require 'tempfile'

describe 'n8l::generate_loader' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }

  # Unfortunately, this example(s) needs to write to the filesystem. While
  # `cat` can be mocked out, bash i/o redirection can not.
  %w[bash csh ksh zsh].each do |sh|
    context sh do
      Tempfile.create(sh) do |f|
        it 'writes file' do
          out, err, status = stubbed_env.execute_function(
            'scripts/newinstall.sh',
            "n8l::generate_loader_#{sh} #{f.path} #{f.path}/python/banana",
          )

          expect(status.exitstatus).to be 0
          expect(out).to eq('')
          expect(err).to eq('')

          expect(File.read(f)).to match(
            /This script is intended to be used with.*#{sh}/
          )
        end
      end
    end
  end
end
