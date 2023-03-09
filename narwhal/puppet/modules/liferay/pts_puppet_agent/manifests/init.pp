class pts_puppet_agent {

  package { 'puppet-agent':
    ensure => latest
  }

  ini_setting { '/etc/puppetlabs/puppet/puppet.conf - server':
    ensure            => present,
    section           => '',
    key_val_separator => ' = ',
    path              => '/etc/puppetlabs/puppet/puppet.conf',
    setting           => 'server',
    value             => $pts_location::puppet_server_hostname,
    require           => Package['puppet-agent']
  }

  ini_setting { '/etc/puppetlabs/puppet/puppet.conf - number_of_facts_soft_limit':
    ensure            => present,
    section           => '',
    key_val_separator => ' = ',
    path              => '/etc/puppetlabs/puppet/puppet.conf',
    setting           => 'number_of_facts_soft_limit',
    value             => '4096',
    require           => Package['puppet-agent']
  }

  file { '/usr/local/sbin/puppet-agent.sh':
    owner  => root,
    group  => root,
    mode   => '0755',
    source => "puppet:///modules/${module_name}/usr/local/sbin/puppet-agent.sh",
  }

  $minute = fqdn_rand(59)

  file { '/etc/cron.d/puppet-agent':
    owner   => root,
    group   => root,
    mode    => '0664',
    content => "# MANAGED BY PUPPET\n${minute} * * * * root /usr/local/sbin/puppet-agent.sh\n"
  }

  if $facts['fqdn'] != $pts_location::puppet_server_hostname {
    pts_hosts::add { $pts_location::puppet_server_ip:
      fqdn    => $pts_location::puppet_server_hostname,
      aliases => [ $pts_location::puppet_server_alias ]
    }
  }
}
