class pts_users::users {

	$hostname_uppercase = upcase($::hostname)

# The 'ubuntu' users should only be deleted, if we are agreed on it with the IT team
#	accounts::user { 'ubuntu':
#		ensure => absent
#	}

	include pts_users::users::brian_chan
	include pts_users::users::peter_mezei
	include pts_users::users::richard_benko
	include pts_users::users::root
	include pts_users::users::szantina_szanto
	include pts_users::users::tamas_papp
	include pts_users::users::ubuntu
	include pts_users::users::zsolt_balogh

}
