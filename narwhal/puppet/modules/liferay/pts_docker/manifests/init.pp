class pts_docker {
  class { 'docker':
    use_upstream_package_source => true,
  }
}
