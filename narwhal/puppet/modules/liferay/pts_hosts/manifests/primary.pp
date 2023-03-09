################################################################################
#
# Class: hosts::primary
#
# This class creates hosts file entry for facts ::fqdn and ::hostname, both
# resolving to fact ::ipaddress.
#
################################################################################
class pts_hosts::primary {

  # do not add primary interface entries if that have been disabled
  unless ( $pts_hosts::primary == false ) {

    # Create entry for localhost
    pts_hosts::add { $::ipdefault:
      fqdn    => $::fqdn,
      aliases => $::hostname,
    }

  }

}
