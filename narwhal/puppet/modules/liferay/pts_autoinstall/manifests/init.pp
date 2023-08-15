class pts_autoinstall {
	file {
		'/var/www/puppet.dso.lfr/docs/a.yaml':
			group => root,
			mode => '0644',
			owner => root,
			source => "puppet:///modules/${module_name}/var/www/puppet.dso.lfr/docs/a.yaml",
	}
}
