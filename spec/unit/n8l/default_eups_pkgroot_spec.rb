# frozen_string_literal: true

require 'rspec/bash'

describe 'n8l::default_eups_pkgroot' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::default_eups_pkgroot' }

  # this function is extremely difficult to test as it uses n8l::sys::*
  # functions, which return values by setting env vars.  Only the 'src' pkgroot
  # may be function tested.
  it 'returns default src pkgroot' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      func,
    )

    expect(out).to match(%r{https://eups.lsst.codes/stack/src})
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  it 'returns default src pkgroot' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} true",
    )

    expect(out).to match(%r{https://eups.lsst.codes/stack/src})
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  it 'does not return the default src pkgroot' do
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "#{func} false",
    )

    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to be 0
  end

  context 'use tarballs' do
    it 'uses LSST_* env vars instead of "probed" values' do
      # prevent probing for system info which might fail
      stubbed_env.stub_command('n8l::sys::osfamily').returns_exitstatus(0)

      out, err, status = stubbed_env.execute_function(
        'scripts/newinstall.sh',
        "#{func} false true",
        {
          'LSST_OS_FAMILY'  => 'redhat',
          'LSST_OS_RELEASE' => '7',
          'LSST_PLATFORM'   => 'el7',
          'LSST_COMPILER'   => 'very-unlikely-string',
        },
      )

      expect(out).to match(%(redhat/el7/very-unlikely-string))
      expect(err).to eq('')
      expect(status.exitstatus).to be 0
    end
  end
end
