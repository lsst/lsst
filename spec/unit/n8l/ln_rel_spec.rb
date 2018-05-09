require 'rspec/bash'

describe 'n8l::ln_rel' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::ln_rel' }

  context 'parameters' do
    context '$1/link_target' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          func,
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/link target is required/)
      end
    end
    context '$2/link_name' do
      it 'is required' do
        out, err, status = stubbed_env.execute_function(
          'scripts/newinstall.sh',
          "#{func} /dne",
        )

        expect(status.exitstatus).to_not be 0
        expect(out).to eq('')
        expect(err).to match(/link name is required/)
      end
    end
  end # parameters

  it 'makes a relative symlink' do
    dirname = stubbed_env.stub_command('dirname').outputs('/dne')
    basename = stubbed_env.stub_command('basename').outputs('target')
    cd = stubbed_env.stub_command('cd')
    readlink = stubbed_env.stub_command('readlink')
    rm = stubbed_env.stub_command('rm')
    ln = stubbed_env.stub_command('ln')

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} /dne/target /dne/name",
    )

    expect(dirname).to be_called_with_arguments('/dne/target').times(1)
    expect(basename).to be_called_with_arguments('/dne/target').times(1)
    expect(cd).to be_called_with_arguments('/dne').times(1)
    expect(readlink).to be_called_with_arguments('target').times(1)
    expect(rm).to be_called_with_arguments('-rf', '/dne/name').times(1)
    expect(ln).to be_called_with_arguments(
      '-sf', 'target', '/dne/name'
    ).times(1)

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to eq('')
  end

  it 'does nothing if symlink exists' do
    dirname = stubbed_env.stub_command('dirname').outputs('/dne')
    basename = stubbed_env.stub_command('basename').outputs('target')
    cd = stubbed_env.stub_command('cd')
    readlink = stubbed_env.stub_command('readlink').outputs('/dne/name')
    rm = stubbed_env.stub_command('rm')
    ln = stubbed_env.stub_command('ln')

    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} /dne/target /dne/name",
    )

    expect(dirname).to be_called_with_arguments('/dne/target').times(1)
    expect(basename).to be_called_with_arguments('/dne/target').times(1)
    expect(cd).to be_called_with_arguments('/dne').times(1)
    expect(readlink).to be_called_with_arguments('target').times(1)
    expect(rm).to_not be_called
    expect(ln).to_not be_called

    expect(status.exitstatus).to be 0
    expect(out).to eq('')
    expect(err).to eq('')
  end
end
