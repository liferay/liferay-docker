class pts_users::users::richard_benko {

	$user = 'richard.benko'
	$real_name = 'Richard Benko'

	accounts::user {
		$user:
			comment => "${real_name} (${pts_users::users::hostname_uppercase})",
			groups => [
				'sudo',
				'ptsaccess',
			],
			sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
			sshkey_group => 'root',
			sshkey_mode => '0644',
			sshkey_owner => 'root',
			sshkeys => [
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOmhD5Dhh+Ek6ZYmZ07zTQwKyuFqjFELAsN6hzR6mgD richard.benko@liferay',
			],
	}

}
