require 'erb'
require 'master_manipulator'
require 'dsc_utils'
test_name 'Apply generic DSC Manifest to create a standard DSC File'

# Manifest
fake_name = SecureRandom.uuid
test_file_contents = SecureRandom.uuid
dsc_manifest = <<-MANIFEST
dsc {'#{fake_name}':
  resource_name => 'file',
  module => 'PSDesiredStateConfiguration',
  properties => {
    ensure          => 'present',
    contents  => '#{test_file_contents}',
    destinationpath => 'C:\\#{fake_name}'
  }
}
MANIFEST

# Teardown
teardown do
  windows_agents.each do |agent|
    teardown_dsc_resource_fixture(agent)
  end

  step 'Remove Test Artifacts'
  on(windows_agents, "rm -rf /cygdrive/c/#{fake_name}")
end

# Tests
windows_agents.each do |agent|
  step 'Copy Test Type Wrappers'
  setup_dsc_resource_fixture(agent)

  step 'Run Puppet Apply'
  on(agent, puppet('apply'), :stdin => dsc_manifest, :acceptable_exit_codes => [0,2]) do |result|
    assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
  end

  step 'Verify Results'
  on(agent, "cat /cygdrive/c/#{fake_name}", :acceptable_exit_codes => [0]) do |result|
    assert_match(/#{test_file_contents}/, result.stdout, 'File contents incorrect!')
  end
end

# New manifest to remove value.
dsc_remove_manifest = <<-MANIFEST
dsc {'#{fake_name}':
  resource_name => 'file',
  module => 'PSDesiredStateConfiguration',
  properties => {
    ensure          => 'absent',
    contents  => '#{test_file_contents}',
    destinationpath => 'C:\\#{fake_name}'
  }
}
MANIFEST

windows_agents.each do |agent|
  step 'Apply Manifest to Remove File'
  on(agent, puppet('apply'), :stdin => dsc_remove_manifest, :acceptable_exit_codes => [0,2]) do |result|
    assert_no_match(/Error:/, result.stderr, 'Unexpected error was detected!')
  end

  step 'Verify Results'
  # if this file exists, 'absent' didn't work
  on(agent, "test -f /cygdrive/c/#{fake_name}", :acceptable_exit_codes => [1])
end