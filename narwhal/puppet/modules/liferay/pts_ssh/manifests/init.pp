# https://forge.puppetlabs.com/saz/ssh
class pts_ssh {

  class { 'ssh':
    storeconfigs_enabled => false,
    validate_sshd_file   => true,
    server_options       => {
      'AuthorizedKeysFile'     => '.ssh/authorized_keys /etc/ssh/auths/%u.pub',
      'PasswordAuthentication' => 'no',
      'PermitRootLogin'        => 'no',
      'PrintMotd'              => 'yes',
      'X11Forwarding'          => 'no',
      'UseDNS'                 => 'no',
    },
  }

  file { '/etc/ssh/auths':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/systemd/system/sshd.service.d':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { '/etc/systemd/system/sshd.service.d/override.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "[Service]\nUMask=007\nOOMScoreAdjust=-900\n",
    notify  => [ Service['ssh'],Exec['systemd_reload'] ],
    require => File['/etc/systemd/system/sshd.service.d'],
  }

}
