################################################################################
#
# Class: hosts::params
#
# Default values for justinjl-hosts
#
################################################################################
class pts_hosts::params {

  $hostsfile   = '/etc/hosts'

  # Hosts file ownership/permissions
  $owner  = 'root'
  $group  = 'root'
  $mode   = '0644'

  # Default options
  $purge     = false
  $localhost = true
  $primary   = true

}

