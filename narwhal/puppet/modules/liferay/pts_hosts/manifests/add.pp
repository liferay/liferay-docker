define pts_hosts::add (
    $fqdn,
    $ipaddr = $name,
    $aliases = undef,
) {

    # Validating $ipaddr ($name) variable
    unless ( is_string( $ipaddr ) ) {
        fail("Error: IP Address ${ipaddr} does not look like an IP Address")
    }

    # Validating $fqdn variable
    unless ( is_string( $fqdn ) ) {
        fail('Error: fqdn must be a string')
    }

    # Validating $aliases variable
    if ( is_array( $aliases ) or is_string( $aliases ) ) {

        # arrays and strings are fine
        $host_aliases = $aliases

    } elsif ( $aliases == undef ) {

        # Undef is fine (does nothing)
        $host_aliases = undef

    } else {

        # Anything else is invalid
        fail('Error: aliases should be a string or an array.')

    }

    host { $ipaddr:
      ensure       => 'present',
      name         => $fqdn,
      host_aliases => $aliases,
      ip           => $ipaddr,
      target       => $pts_hosts::hostsfile,
    }

}
