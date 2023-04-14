class pts_timezone {

	class {
		'timezone':
			autoupgrade => true,
			hwutc => true,
			timezone => $pts_location::timezone,
	}
}
