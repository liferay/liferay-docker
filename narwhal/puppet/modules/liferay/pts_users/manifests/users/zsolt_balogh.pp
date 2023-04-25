class pts_users::users::zsolt_balogh {

	$user = 'zsolt.balogh'
	$real_name = 'Zsolt Balogh'

	accounts::user {
		$user:
			comment => "Zsolt Balogh (${pts_users::users::hostname_uppercase})",
			groups => [
				'ptsaccess',
				'sudo',
			],
			sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
			sshkey_group => 'root',
			sshkey_mode => '0644',
			sshkey_owner => 'root',
			sshkeys => [
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOu945eSM8vlNkxMmnYrIYkoFaPO0L7+M0cWnV8/tH2 zsolt.balogh@liferay',
			],
	}

}
