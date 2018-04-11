require 'rspec/bash'

describe 'n8l::fmt' do
  include Rspec::Bash

  let(:stubbed_env) { create_stubbed_env }
  subject(:func) { 'n8l::fmt' }

  it 'does not split short strings' do
    text = 'a b c d e f g'
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "echo -n $TEXT | #{func}",
      {
        'TEXT' => text
      }
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq(text + "\n")
    expect(err).to eq('')
  end

  it 'does not split continous strings' do
    text = 'a' * 1000
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "echo -n $TEXT | #{func}",
      {
        'TEXT' => text
      }
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq(text + "\n")
    expect(err).to eq('')
  end

  it 'backfills multiple short lines' do
    text = "a\nb\nc\nd\ne\nf\ng"
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "echo -n $TEXT | #{func}",
      {
        'TEXT' => text
      }
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq("a b c d e f g\n")
    expect(err).to eq('')
  end

  it 'splits at 78 chars' do
    text = 'a' * 78
    text += ' ' + text
    out, err, status = stubbed_env.execute_function(
      'scripts/newinstall.sh',
      "echo -n $TEXT | #{func}",
      {
        'TEXT' => text
      }
    )

    expect(status.exitstatus).to be 0
    expect(out).to eq(text.tr(' ', "\n") + "\n")
    expect(err).to eq('')
  end
end
