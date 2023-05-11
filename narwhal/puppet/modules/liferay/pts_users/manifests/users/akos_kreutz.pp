class pts_users::users::akos_kreutz {

	$user = 'akos.kreutz'
	$real_name = 'Akos Kreutz'

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
				'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9jWlqzMEHbOfyTHvjK7xFtqUTVS8A8fn2TwUE4HLIpjPzbaST760gju/rUZMTczgjEr6QR99TTZH5nnoPrwBZlk1W3/2IiTuM7F4OydTuIRfdZOp7e9PpnMcGa9vulkt1Aj1trJ1IF9qAnLyReFUaUrRqvq9Yj3s6kfer2OSRqHkhd49Al9KYJinoiuZh891Q9O+SWua0bGV49mOyhdgNa5X06OrYRUb54MiHH8TTxYUsU+2c2yN4oK0jQuvyjDbsFPSkulQefyPkTVd/InfngWjTUXRkRX84MLAGK5r+Yl2XR1w7Yhuo8npqUEubtjObvgVopMj2tC4gBfRvqsm5Bd8Oc5GYcxwhSnE6siefr1Rp16M/mOQiBe+jUxNqkcfBWy2FyeRiV7bopZR6zNDqLsXJ/xKdkyOq027L380sxGpnDYNHi+glRF15kLpL87t1MxWbqZcPGAFujOnRHbNSktaw+aFEuRrGSiu6v3aKRGzEDTJJkUlMjwcybQG+aJd6CHRKSOqESxJmozvNpdsjpZT24glxZ/PLpeUqkC5EEw6iE1KWvCTc7s5ncR7EdwIs5rQhGH/1rRv5S1pjQZNnzeBIERuRLY11QStedy6Ck0vp5DFrZ7dT3MfSNjBokvpcKd+ZP9R/CCVJReFbHvFxksROsCX2ymRZuXoLpEiLFw== akos.kreutz@private',
			],
	}

}
