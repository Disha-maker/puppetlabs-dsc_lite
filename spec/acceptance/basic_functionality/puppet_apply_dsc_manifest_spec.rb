require 'spec_helper_acceptance'

describe 'Puppet apply tests' do
  test_dir_path = SecureRandom.uuid
  fake_name = SecureRandom.uuid
  test_file_contents = SecureRandom.uuid

  dsc_manifest = <<-MANIFEST
    file { 'C:/#{test_dir_path}' :
       ensure => 'directory'
    }
    ->
    dsc { '#{fake_name}':
      resource_name => 'puppetfakeresource',
      module => '#{installed_path}/1.0',
      properties => {
        ensure          => 'present',
        importantstuff  => '#{test_file_contents}',
        destinationpath => '#{'C:\\' + test_dir_path + '\\' + fake_name}',
      },
    }
  MANIFEST

  test_dir_path_b = SecureRandom.uuid
  fake_name_b = SecureRandom.uuid

  dsc_manifest_b = <<-MANIFEST
    file { 'C:/#{test_dir_path}' :
       ensure => 'directory'
    }
    ->
    dsc { '#{fake_name_b}':
      resource_name => 'puppetfakeresource',
      module => '#{installed_path}/1.0',
      properties => {
        ensure          => 'present',
        importantstuff  => '#{SecureRandom.uuid}',
        destinationpath => '#{'C:\\' + test_dir_path + '\\' + fake_name}',
      },
    }
  MANIFEST

  context 'FM-2625 - Apply DSC Resource Manifest via "puppet apply"' do
    it 'applies dsc_lite manifest via puppet apply' do
      execute_manifest(dsc_manifest, catch_failures: true) do |result|
        assert_no_match(%r{Error:}, result.stderr, 'Unexpected error was detected!')
        assert_match(%r{Stage\[main\]\/Main\/Dsc\[#{fake_name}\]/ensure\: invoked}, result.stdout, 'DSC Resource missing!')
      end
    end

    it 'file contains correct contents' do
      # PuppetFakeResource always overwrites file at this path
      on(windows_agents, "cat /cygdrive/c/#{test_dir_path}/#{fake_name}", acceptable_exit_codes: [0]) do |result|
        assert_match(%r{#{test_file_contents}}, result.stdout, 'PuppetFakeResource File contents incorrect!')
      end
    end
  end

  context 'FM-2623 - Apply DSC Resource Manifest in "noop" Mode Using "puppet apply"' do
    it 'Applies noop manifest' do
      on(windows_agents, puppet('apply --noop --detailed-exitcodes'), stdin: dsc_manifest_b, acceptable_exit_codes: [0, 2]) do |result|
        assert_no_match(%r{Error:}, result.stderr, 'Unexpected error was detected!')
      end
    end

    it 'Made no changes' do
      # if this file exists, noop didn't work
      on(windows_agents, "test -f /cygdrive/c/#{test_dir_path_b}/#{fake_name_b}", acceptable_exit_codes: [1])
    end
  end

  before(:all) do
    windows_agents.each do |agent|
      setup_dsc_resource_fixture(agent)
    end
  end

  after(:all) do
    on(windows_agents, "rm -rf /cygdrive/c/#{test_dir_path}")
    windows_agents.each do |agent|
      teardown_dsc_resource_fixture(agent)
    end
  end
end
