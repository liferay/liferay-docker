################################################################################
#
# Class: hosts::file
#
# This class declares the file and empties its content if $purge is set.
#
################################################################################
class pts_hosts::file {

    file { $pts_hosts::hostsfile:
      owner => $pts_hosts::owner,
      group => $pts_hosts::group,
      mode  => $pts_hosts::mode,
    }

    if ( $pts_hosts::purge == true ) {
      resources { 'host' :
        purge   => true
      }
    }

}

