class pts_users::users::brian_chan {

	$user = 'brian.chan'
	$real_name = 'Brian Chan'

	accounts::user {
		$user:
			comment => "${real_name} (${pts_users::users::hostname_uppercase})",
			groups => [
				'ptsaccess',
				'sudo',
			],
			sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
			sshkey_group => 'root',
			sshkey_mode => '0644',
			sshkey_owner => 'root',
	}

}
