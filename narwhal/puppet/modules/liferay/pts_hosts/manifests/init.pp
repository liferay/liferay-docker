class pts_hosts ($group = $pts_hosts::params::group,
	$hostsfile = $pts_hosts::params::hostsfile,
	$localhost = $pts_hosts::params::localhost,
	$mode = $pts_hosts::params::mode,
	$owner = $pts_hosts::params::owner, $primary = $pts_hosts::params::primary,
	$purge = $pts_hosts::params::purge
) inherits pts_hosts::params {

	anchor {
		'pts_hosts::begin':
	} -> class {
		'pts_hosts::file':
	} -> class {
		'pts_hosts::localhost':
	} -> class {
		'pts_hosts::primary':
	} -> anchor {
		'pts_hosts::end':
	}

}