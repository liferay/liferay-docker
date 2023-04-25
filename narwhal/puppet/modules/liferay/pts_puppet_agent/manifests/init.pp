class pts_puppet_agent {

	package {
		'puppet-agent':
			ensure => latest
	}

	ini_setting {
		'/etc/puppetlabs/puppet/puppet.conf - server':
			ensure => present,
			key_val_separator => ' = ',
			path => '/etc/puppetlabs/puppet/puppet.conf',
			require => Package['puppet-agent'],
			section => '',
			setting => 'server',
			value => $pts_location::puppet_server_hostname,
	}

	ini_setting {
		'/etc/puppetlabs/puppet/puppet.conf - number_of_facts_soft_limit':
			ensure => present,
			key_val_separator => ' = ',
			path => '/etc/puppetlabs/puppet/puppet.conf',
			require => Package['puppet-agent'],
			section => '',
			setting => 'number_of_facts_soft_limit',
			value => '4096',
	}

	file {
		'/usr/local/sbin/puppet-agent.sh':
			group => root,
			mode => '0755',
			owner => root,
			source => "puppet:///modules/${module_name}/usr/local/sbin/puppet-agent.sh",
	}

	$minute = fqdn_rand(59)

	file {
		'/etc/cron.d/puppet-agent':
			content => "# MANAGED BY PUPPET\n${minute} * * * * root /usr/local/sbin/puppet-agent.sh\n",
			group => root,
			mode => '0664',
			owner => root,
	}

	if $facts['fqdn'] != $pts_location::puppet_server_hostname {
		pts_hosts::add {
				$pts_location::puppet_server_ip:
					fqdn => $pts_location::puppet_server_hostname,
					aliases => [ $pts_location::puppet_server_alias ]
		}

	}

}
