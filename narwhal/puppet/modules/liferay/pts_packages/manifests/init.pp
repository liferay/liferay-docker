class pts_packages {

  include pts_packages::absent
  include pts_packages::latest

  $minute = fqdn_rand(59)

  file { '/etc/cron.d/backup-deb-packages-export':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${minute} 22 * * * root /usr/bin/dpkg -l | grep '^ii' | awk \'{ print \$2 }\' | sort > /etc/deb_packages.list 2>&1\n"
  }

}
