################################################################################
#
# Class: hosts
#
################################################################################
class pts_hosts (
  $hostsfile  = $pts_hosts::params::hostsfile,
  $owner      = $pts_hosts::params::owner,
  $group      = $pts_hosts::params::group,
  $mode       = $pts_hosts::params::mode,
  $purge      = $pts_hosts::params::purge,
  $localhost  = $pts_hosts::params::localhost,
  $primary    = $pts_hosts::params::primary,
) inherits pts_hosts::params {

  anchor {'pts_hosts::begin': } -> class {'pts_hosts::file': } -> class {'pts_hosts::localhost': } -> class {'pts_hosts::primary': } -> anchor { 'pts_hosts::end': }

}
