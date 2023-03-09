class pts_users::users::peter_mezei {

  $user = 'peter.mezei'

  accounts::user { $user:
    comment            => "Peter Mezei (${pts_users::users::hostname_uppercase})",
    groups             => ['sudo','ptsaccess'],
    sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
    sshkey_owner       => 'root',
    sshkey_group       => 'root',
    sshkey_mode        => '0644',
    sshkeys            => [
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGONWS4sxm0N2gVn9cg02yeVV4Op32gZonA+4pgXN0q peter.mezei@liferay',
    ],
  }
}
