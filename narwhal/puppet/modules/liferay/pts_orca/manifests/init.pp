class pts_orca {

	include pts_docker
	include snap

	package {
		'pwgen':
			ensure => latest
	}

	package {
		'yq':
			ensure => installed,
			provider => 'snap',
	}

}
