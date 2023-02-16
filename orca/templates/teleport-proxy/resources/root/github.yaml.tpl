kind: github
version: v3
metadata:
  # Connector name that will be used with `tsh --auth=github login`
  name: github
spec:
  # Client ID of your GitHub OAuth App
  client_id: __GITHUB_ID__
  # Client secret of your GitHub OAuth App
  client_secret: __GITHUB_SECRET__
  # Connector display name that will be shown on the Web UI login screen
  display: GitHub
  # Callback URL that will be called after successful authentication
  redirect_url: https://localhost:3080/v1/webapi/github/callback
  # Mapping of org/team memberships onto allowed roles
  teams_to_roles:
    - organization: liferay-orca-test # GitHub organization name
      team: admins # GitHub team name within that organization
      roles:
        ##########################################################
        #  ROLES TO BE GIVEN TO THE USER IN THE TELEPORT SYSTEM  #
        ##########################################################
        - access
        - editor