class pts_ci_node {
	Class['docker'] -> Class['pts_users::users::jenkins']
	include docker
	include pts_users::users::jenkins
	include snap

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