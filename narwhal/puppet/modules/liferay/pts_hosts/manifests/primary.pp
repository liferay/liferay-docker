class pts_hosts::primary {

	unless ( $pts_hosts::primary == false ) {

		pts_hosts::add {
			$::ipdefault:
				aliases => $::hostname,
				fqdn => $::fqdn,
		}

	}

}
