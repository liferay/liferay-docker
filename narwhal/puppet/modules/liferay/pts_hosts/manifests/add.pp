define pts_hosts::add($aliases = undef, $fqdn, $ipaddr = $name) {
	unless (is_string($ipaddr)) {
		fail("Error: IP Address ${ipaddr} does not look like an IP Address")
	}

	unless (is_string($fqdn)) {
		fail('Error: fqdn must be a string')
	}

	if (is_array($aliases) or is_string($aliases)) {
		$host_aliases = $aliases
	}
	elsif ($aliases == undef) {
		$host_aliases = undef
	}
	else {
		fail('Error: aliases should be a string or an array.')

	}

	host {
		$ipaddr:
			ensure => 'present',
			name => $fqdn,
			host_aliases => $aliases,
			ip => $ipaddr,
			target => $pts_hosts::hostsfile,
	}
}