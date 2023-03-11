class pts_orca {

  include pts_docker

  package { 'pwgen':
    ensure => latest,
  }

  include snap

  package { 'yq':
    ensure   => installed,
    provider => 'snap',
  }

}
