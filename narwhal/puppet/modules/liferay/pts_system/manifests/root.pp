class pts_system::root {
	file {
		'/root/.bash_profile':
			group => root,
			mode => '0644',
			owner => root,
			source => "puppet:///modules/${module_name}/root/.bash_profile",
	}
}
