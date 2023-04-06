node /^gw1.orca.lfr$/ {
	include pts_system

	pts_hosts::add {
		'10.111.111.111': fqdn => 'db1.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.112': fqdn => 'db2.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.11': fqdn => 'jenkins.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.10': fqdn => 'jumper.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.12': fqdn => 'observer.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.121': fqdn => 'search1.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.122': fqdn => 'search2.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.123': fqdn => 'search3.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.101': fqdn => 'web1.orca.lfr'
	}

	pts_hosts::add {
		'10.111.111.102': fqdn => 'web2.orca.lfr'
	}
}