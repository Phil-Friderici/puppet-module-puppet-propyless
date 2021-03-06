class puppet::agent (
  $agent_service   = $::puppet::client_agent_service,
) inherits ::puppet {
  # Make sure that this class can only be called by this module.
  assert_private('puppet::agent is a private class and can not be called directly')

  validate_hash($agent_service)

  if has_key($agent_service, 'type') {
    validate_re($agent_service['type'], ['^cron$'])

    case $agent_service['type'] {
      'cron': {

        $cron_args = pick(
          $agent_service['puppet_args'],
          'agent --onetime --ignorecache --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay'
        )
        $puppet_bin  = pick($agent_service['puppet_bin'], '/opt/puppetlabs/bin/puppet')
        $cron_user   = pick($agent_service['user'], 'root')
        $cron_ensure = pick($agent_service['ensure'], 'present')
        $cron_hour   = pick($agent_service['hour'], '*')
        $cron_struct = pick($agent_service['cron_structure'], '%{puppet_bin} %{puppet_args}')

        # Calculate the $cron_minute
        $_run_interval = pick($agent_service['interval'], 30)
        # Validate the run_interval value to make sure its a numeric and not above 60 (1 hour)
        validate_integer($_run_interval, 60)
        $_cron_minute_1 = pick($agent_service['minute'], fqdn_rand($_run_interval))

        if $_run_interval <= 30 and $agent_service['minute'] == undef {
          $_cron_minute_2 = $_cron_minute_1 + 30
          $cron_minute = [$_cron_minute_1, $_cron_minute_2]
        }
        else {
          $cron_minute = $agent_service['minute']
        }

        $_cron_cmd_real = regsubst($cron_struct, '%\{puppet_bin\}', $puppet_bin)
        $cron_cmd_real  = regsubst($_cron_cmd_real, '%\{puppet_args\}', $cron_args)

        cron { 'puppet_cron_interval':
          ensure  => $cron_ensure,
          user    => $cron_user,
          command => $cron_cmd_real,
          minute  => $cron_minute,
          hour    => $cron_hour,
        }
      }
      default: {
        # satisfy puppet-lint
      }
    }
  }
  else {
    fail('$puppet::client::agent_version must include a type.')
  }
}