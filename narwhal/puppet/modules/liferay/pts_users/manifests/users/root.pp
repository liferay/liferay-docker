class pts_users::users::root {
	$user = 'root'

	accounts::user {
		$user:
			comment => "${pts_users::users::hostname_uppercase} root",
	}
}
