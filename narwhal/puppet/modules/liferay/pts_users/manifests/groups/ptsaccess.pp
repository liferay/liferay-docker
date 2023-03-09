class pts_users::groups::ptsaccess {

  group { 'ptsaccess':
    ensure  => present,
  }

  sudo::conf { 'ptsaccess':
    priority => 10,
    content  => '%ptsaccess ALL=(ALL) NOPASSWD: ALL',
    }
}
