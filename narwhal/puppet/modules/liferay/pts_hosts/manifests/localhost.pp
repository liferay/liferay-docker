################################################################################
#
# Class: hosts::localhost
#
# This class adds localhost entries (ipv4, optionally ipv6) to the hosts file
#
################################################################################
class pts_hosts::localhost {

  # Do not add localhost entries if they have been disabled
  unless ( $pts_hosts::localhost == false ) {

    # Create entry for localhost
    pts_hosts::add { '127.0.0.1' :
        fqdn    => 'localhost.localdomain',
        aliases => 'localhost',
    }

    # Create entries for ipv6 localhost
    pts_hosts::add { '::1' :
        fqdn    => 'localhost6.localdomain6',
        aliases => [ 'localhost6', 'ip6-localhost', 'ip6-loopback' ],
    }
    pts_hosts::add { 'fe00::0' :
        fqdn    => 'ip6-localnet',
    }
    pts_hosts::add { 'ff00::0' :
        fqdn    => 'ip6-mcastprefix',
    }
    pts_hosts::add { 'ff02::1' :
        fqdn    => 'ip6-allnodes',
    }
    pts_hosts::add { 'ff02::2' :
        fqdn    => 'ip6-allrouters',
    }

  }

}

