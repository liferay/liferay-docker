class pts_users::users::jenkins {

	$user = 'jenkins'
	$real_name = 'Jenkins'

	accounts::user {
		$user:
			comment => "${real_name} (${pts_users::users::hostname_uppercase})",
			gid => 1000,
			groups => [
				'docker',
				'ptsaccess',
			],
			sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
			sshkey_group => 'root',
			sshkey_mode => '0644',
			sshkey_owner => 'root',
			sshkeys =>
				[
				'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDLzDAYeiaDNX1bZo3v6UfzIuTXHZ5a3+bmMZ/ekYsnLdynrOV2Czo+k0srjz7oSDY0DK4sMJWMfGMMGMSicUteCVYVyA/KLWweF6GpSzCh27VISwG9t05CDqTNm8/E8ACSJ2IZwTUeAZnTkDPqT/wZC+0xhfMX+aMmdWSHo0NVNhtU75FyCKeYStz5BLi3UNx+/w8dqQUHkGSmtLzj0IwXUgsQ1TS4reAthRNnihF7LBA2RntHaO2d1zgy4pvRPtPgVt9m0FHddhGedZ8YlSNcCG6AxlaZ6eI8Rl0OJarEg8nnwwZaOfqoJIXp6/TBq9LCxpt4RhYLTPd5XPWn8w/sQfpEZyJwohRoSOXPYDUChykDxn+V/78QcDF7oIJq9dcTs/D1jgHaMWi/REG77lENuuoAhEpk7S/6eGjGgG8yHghS65xQ6JWTH+FHnUqksFwyvVYQNkJ2nLrc5GCYIuSnCWHVxl5yk2jzs8da9DNNiGsSwFWYAOTzBV11Leq5GSM= jenkins@bob1',
			],
			uid => 1000,
	}

}
