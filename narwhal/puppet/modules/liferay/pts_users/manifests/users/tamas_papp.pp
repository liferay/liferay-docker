class pts_users::users::tamas_papp {

	$user = 'tamas.papp'
	$real_name = 'Tamas Papp'

	accounts::user {
		$user:
			comment => "Tamas PAPP (${pts_users::users::hostname_uppercase})",
			groups => [
				'sudo',
				'ptsaccess',
			],
			sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
			sshkey_group => 'root',
			sshkey_mode => '0644',
			sshkey_owner => 'root',
			sshkeys => [
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9cRilRehhA3bBKZfd8OITMFVyzQBUvCjvbejLsJavD tamas.papp@private',
			],
	}

}
