class pts_threatstack {
	file { '/etc/apt/trusted.gpg.d/threatstack.gpg':
		group => root,
		mode => '0644',
		owner => root,
		source => "puppet:///modules/${module_name}/etc/apt/trusted.gpg.d/threatstack.gpg",
	}

	file { '/etc/apt/sources.list.d/threatstack.list':
		content => "deb https://pkg.threatstack.com/v2/Ubuntu ${facts['os']['distro']['codename']} main\n",
		group => root,
		mode => '0644',
		notify => Class['apt::update'],
		owner => root,
		require => File['/etc/apt/trusted.gpg.d/threatstack.gpg'],
	}

	package { 'threatstack-agent':
		ensure  => latest,
		require => File['/etc/apt/sources.list.d/threatstack.list'],
	}

	service { 'threatstack':
		ensure   => running,
		provider => 'systemd',
		require  => Package['threatstack-agent'],
	}
}
