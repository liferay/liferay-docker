class pts_timezone {

  class { 'timezone':
    timezone    => $pts_location::timezone,
    autoupgrade => true,
    hwutc       => true,
  }
}
