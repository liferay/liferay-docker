class pts_location {

  file { '/usr/local/sbin/ifdefault.sh':
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => "puppet:///modules/${module_name}/usr/local/sbin/ifdefault.sh"
  }

  case $::networkdefault {
    '192.168.232.0': {
      $location = 'bpo-ci'
      $prompt_host_color = 'cyan'
      $puppet_server_hostname = 'bob1.bud.liferay.com'
      $puppet_server_ip = '192.168.233.201'
      $puppet_server_alias = 'pts-bpo.bud.liferay.com'
      $timezone = 'Europe/Budapest'
    }

    default: {
      fail("\n\nCannot identify location, unknown default network: ${::networkdefault}!\n\n")
    }
  }

  notify { "Location: ${location}":
  }
}
