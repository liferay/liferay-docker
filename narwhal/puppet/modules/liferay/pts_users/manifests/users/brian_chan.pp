class pts_users::users::brian_chan {

  $user = 'brian.chan'

  accounts::user { $user:
    comment            => "Brian Chan (${pts_users::users::hostname_uppercase})",
    groups             => ['sudo','ptsaccess'],
    sshkey_custom_path => "/etc/ssh/auths/${user}.pub",
    sshkey_owner       => 'root',
    sshkey_group       => 'root',
    sshkey_mode        => '0644',
    #sshkeys            => [
    #  '',
    #],
  }
}
