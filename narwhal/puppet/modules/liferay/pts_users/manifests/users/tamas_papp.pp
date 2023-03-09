class pts_users::users::tamas_papp {

  $user = 'tamas.papp'

  accounts::user { $user:
    comment            => "Tamas PAPP (${pts_users::users::hostname_uppercase})",
    groups             => ['sudo','ptsaccess'],
    sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
    sshkey_owner       => 'root',
    sshkey_group       => 'root',
    sshkey_mode        => '0644',
    sshkeys            => [
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9cRilRehhA3bBKZfd8OITMFVyzQBUvCjvbejLsJavD tamas.papp@private',
    ],
  }
}
