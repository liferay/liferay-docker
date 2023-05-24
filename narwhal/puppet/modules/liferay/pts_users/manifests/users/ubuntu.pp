class pts_users::users::ubuntu {

	$user = 'ubuntu'
	$real_name = 'ubuntu'

	accounts::user {
		$user:
			comment => "${real_name} (${pts_users::users::hostname_uppercase})",
			groups => [
				'ptsaccess',
				'sudo',
			],
			password => '$6$Asmc5Pso43vsKDTE$E8rWaDRbfwiv.fCz4g1gr0wB5P1FqpWJ58yB70x9zB2udfdhJRfkwaIsOzpk9qokrBuex3Mdult8wn0KnB1fE1',
			sshkeys =>
				[
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAZpQXHpHb+8SuvAsJgK0DihB70GovopWAW7gwKUIK6Q kiyoshi.lee@liferay.com',
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAijYuQ009czfSEiVtWyra39vNy9Y803yJcaD2IDJ9zK ansible-runner',
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGONWS4sxm0N2gVn9cg02yeVV4Op32gZonA+4pgXN0q petermezei-lr@github/76655988 # ssh-import-id gh:petermezei-lr',
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFOmhD5Dhh+Ek6ZYmZ07zTQwKyuFqjFELAsN6hzR6mgD richard.benko@liferay.com',
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFkDDO7aanqo0rc93PLS/GLzautv01ldODB4ES3HMlfU william.forsyth@liferay.com',
				'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9cRilRehhA3bBKZfd8OITMFVyzQBUvCjvbejLsJavD tompos@private',
				'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDBDvSl4fpegUX1BAoVrNJUGrY9/VXDCOlzkbuSb3mUvYfK+ZmeU8Si4GjSbtJPjB64TR83MxEygxXV2SNXgdyHyFrNNrgBJox2RScOnHE8/FvDAMl7iXMAdcQG5XST+DVX4WoomD/vhuS4UJPQnDSE9mXPrd7g4dU8Jw9hOmnrR0qPA0eSKjn2jJdV9haSP0cwF4gach91xqCHAFOfeBcSV5NzZB52uc24UeJzkHFXdgSb3B16bRJK5Bj/uK2ttDsiukkYfWojB14gSm1XwkxgiJ3ktBCjfnPeI9z5BPWkY1M/Okh9tKJCBGkq5VQBQtcnDLJmnUsLY6uuq1kZO22IYoN2sdn/8QVxAIAIjkH2qJcAN1GN/85dZlB7IjwErCO1idWpo1v24cqZCIDE3tR2DWuO8SFwrzfr6BHsBlHC53V3iF1yooWk5bj2eKspKZzt6TJxAWGxYb3EEssh0NpV4guh6QtERpaeYALV5ZkmHNlJnG9tzghx7Q1qzjiJrk8= me@liferay-m0t0d7m6',
			],
	}

}
