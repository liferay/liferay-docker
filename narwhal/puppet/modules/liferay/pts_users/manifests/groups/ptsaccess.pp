class pts_users::groups::ptsaccess {

	group {
		'ptsaccess':
			ensure => present,
	}

	sudo::conf {
		'ptsaccess':
			content => '%ptsaccess ALL=(ALL) NOPASSWD: ALL',
			priority => 10,
	}

}
