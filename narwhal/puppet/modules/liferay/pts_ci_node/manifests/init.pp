class pts_ci_node {
	Class['docker'] -> Class['pts_users::users::jenkins']
	include docker
	include pts_threatstack
	include pts_users::users::jenkins
	include snap

	file {
		'/data':
			ensure => directory,
			group => root,
			mode => '0755',
			owner => root,
	}

	file {
		'/data/jenkins':
			ensure => directory,
			group => root,
			mode => '0755',
			owner => root,
			require => File['/data'],
	}

	file {
		'/data/jenkins/narwhal':
			ensure => directory,
			group => jenkins,
			mode => '0755',
			owner => jenkins,
			require => File['/data/jenkins'],
	}

	package {
		[
			'jq',
			'openjdk-11-jdk',
			'p7zip-full',
		]:
		ensure => latest
	}

	package {
		'yq':
			ensure => installed,
			provider => 'snap',
	}
}