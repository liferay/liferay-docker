# Release / hotfix builder

## Parameters

 - `NARWHAL_BUILD_ID`: The number of the hotfix
 - `NARWHAL_DEBUG`: Set to anything and it will print the logs to the console instead of file.
 - `NARWHAL_GIT_SHA`: The git tag or branch in the `liferay-portal-ee` repository to build from
 - `NARWHAL_OUTPUT`: release or hotfix
 - `NARWHAL_REMOTE`: The name of the GitHub for to use, by default it's liferay
 - `NARWHAL_TEST_HOTFIX_CHERRY_PICK_SHA`: If this is set, the hotfix builder will cherrypick the given SHA before building the code

## Other configuration
 - Add a release to the test_update folder as a .7z to test against
 - Delete the build folder after every build to get clean results