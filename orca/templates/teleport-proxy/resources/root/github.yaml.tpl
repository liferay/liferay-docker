kind: github
metadata:
    name: github
spec:
    client_id: __GITHUB_ID__
    client_secret: __GITHUB_SECRET__
    display: GitHub
    redirect_url: https://__GITHUB_REDIRECT_HOST__:3080/v1/webapi/github/callback
    teams_to_roles:
        - organization: liferay-orca-test
            roles:
                - access
                - editor
            team: admins
version: v3