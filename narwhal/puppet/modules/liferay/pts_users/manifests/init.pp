class pts_users {

	Class['pts_users::groups'] -> Class['pts_users::users']

	include pts_users::groups
	include pts_users::users
}
