class pts_system {

	Class['pts_ssh'] -> Class['pts_users']

	include pts_location
	include pts_packages
	include pts_puppet_agent
	include pts_schedule
	include pts_ssh
	include pts_system::root
	include pts_timezone
	include pts_users

	class {
		'locales':
			default_locale => 'C.UTF-8',
			locales => [
				'en_US.UTF-8 UTF-8',
			],
	}

	class {
		'pts_hosts':
			purge => true
	}

	class {
		'sudo':
			package_ensure => latest,
			purge_ignore => '*[!_puppet]',
			suffix => '_puppet',
	}

	exec {
		'systemd_reload':
			command => '/bin/systemctl daemon-reload',
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
			content => 'Defaults	env_keep = "PATH XAUTHORITY SSH_AUTH_SOCK GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL"',
			priority => 20,
	}

	sudo::conf {
		'admins':
			content => '%admins ALL=(ALL) NOPASSWD:ALL',
			ensure => present,
	}

	sudo::conf {
		'sudo':
			content => '%sudo ALL=(ALL) NOPASSWD:ALL',
			ensure => present,
	}

}
