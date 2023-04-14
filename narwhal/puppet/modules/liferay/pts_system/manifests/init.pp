class pts_system {

	Class['pts_ssh'] -> Class['pts_users']

	include pts_location
	include pts_packages
	include pts_puppet_agent
	include pts_schedule
	include pts_ssh
	include pts_timezone
	include pts_users

	class {
		'pts_hosts':
			purge => true
	}

	class {
		'sudo':
			suffix => '_puppet',
			purge_ignore => '*[!_puppet]',
			package_ensure => latest,
	}

	exec {
		'systemd_reload':
			command	=> '/bin/systemctl daemon-reload',
			refreshonly => true,
	}

	file {
		'/usr/local/bin/ssh-clean-known_hosts.sh':
			group => root,
			mode => '0755',
			owner => root,
			source => "puppet:///modules/${module_name}/usr/local/bin/ssh-clean-known_hosts.sh",
	}

	file_line {
		'/etc/systemd/system.conf - DefaultLimitNOFILE':
			line => 'DefaultLimitNOFILE=65534',
			match => '^#?DefaultLimitNOFILE=',
			path => '/etc/systemd/system.conf',
	}

	sudo::conf {
		'git_env':
			priority => 20,
			content	=> 'Defaults	env_keep = "PATH XAUTHORITY SSH_AUTH_SOCK GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL"',
	}

	sudo::conf {
		'admins':
			ensure	=> present,
			content => '%admins ALL=(ALL) NOPASSWD:ALL',
	}

	sudo::conf {
		'sudo':
			ensure	=> present,
			content => '%sudo ALL=(ALL) NOPASSWD:ALL',
	}

}
