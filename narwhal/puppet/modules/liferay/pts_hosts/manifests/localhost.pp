class pts_hosts::localhost {

	unless ($pts_hosts::localhost == false) {

		pts_hosts::add {
			'127.0.0.1':
				aliases => 'localhost',
				fqdn => 'localhost.localdomain',
		}

		pts_hosts::add {
			'::1':
				aliases => [
					'ip6-localhost',
					'ip6-loopback',
					'localhost6',
				],
				fqdn => 'localhost6.localdomain6',
		}

		pts_hosts::add {
			'fe00::0':
				fqdn => 'ip6-localnet'
		}

		pts_hosts::add {
			'ff00::0':
				fqdn => 'ip6-mcastprefix'
		}

		pts_hosts::add {
			'ff02::1':
				fqdn => 'ip6-allnodes'
		}

		pts_hosts::add {
			'ff02::2' :
				fqdn => 'ip6-allrouters'
		}

	}

}