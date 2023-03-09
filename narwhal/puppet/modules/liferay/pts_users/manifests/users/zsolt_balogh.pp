class pts_users::users::zsolt_balogh {

  $user = 'zsolt.balogh'

  accounts::user { $user:
    comment            => "Zsolt Balogh (${pts_users::users::hostname_uppercase})",
    groups             => ['sudo','ptsaccess'],
    sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
    sshkey_owner       => 'root',
    sshkey_group       => 'root',
    sshkey_mode        => '0644',
    sshkeys            => [
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOu945eSM8vlNkxMmnYrIYkoFaPO0L7+M0cWnV8/tH2 zsolt.balogh@liferay',
    ],
  }
}
