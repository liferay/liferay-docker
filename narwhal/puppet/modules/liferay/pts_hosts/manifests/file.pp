class pts_hosts::file {
	file {
		$pts_hosts::hostsfile:
			group => $pts_hosts::group,
			mode => $pts_hosts::mode,
			owner => $pts_hosts::owner,
	}

	if ($pts_hosts::purge == true) {

		resources {
				'host':
					purge => true
		}

	}

}