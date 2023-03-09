class pts_users::users {

  $hostname_uppercase = upcase($::hostname)

# should be activated if we're agreed on it with local IT
#  accounts::user { 'ubuntu':
#    ensure => absent
#  }

  include pts_users::users::brian_chan
  include pts_users::users::peter_mezei
  include pts_users::users::richard_benko
  include pts_users::users::root
  include pts_users::users::tamas_papp
  include pts_users::users::zsolt_balogh
}
