# documentation: https://forge.puppetlabs.com/saz/ssh

class pts_ssh {

	class {
		'ssh':
			server_options => {
				'AuthorizedKeysFile' => '.ssh/authorized_keys /etc/ssh/auths/%u.pub',
				'PasswordAuthentication' => 'no',
				'PermitRootLogin' => 'no',
				'PrintMotd' => 'yes',
				'UseDNS' => 'no',
				'X11Forwarding' => 'yes',
			},
			storeconfigs_enabled => false,
			validate_sshd_file => true,
	}

	file {
		'/etc/ssh/auths':
			ensure => directory,
			group => 'root',
			mode => '0755',
			owner => 'root',
	}

	file {
		'/etc/systemd/system/sshd.service.d':
			ensure => directory,
			group => 'root',
			mode => '0755',
			owner => 'root',
	}

	file {
		'/etc/systemd/system/sshd.service.d/override.conf':
			content => "[Service]\nUMask=007\nOOMScoreAdjust=-900\n",
			group => 'root',
			mode => '0644',
			notify => [ Service['ssh'],Exec['systemd_reload'] ],
			owner => 'root',
			require => File['/etc/systemd/system/sshd.service.d'],
	}

}
