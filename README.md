# liferay-docker repository

## Development
To speed up development, here are some tips:
 - To run the last built docker image run: ``docker run `docker images -q | head -n1` ``
 - To test changes to the entrypoint script without rebuilding, mount the `templates/scripts` folder from your `liferay-docker` repository to `/usr/local/bin`: `-v $PWD/template/scripts:/usr/local/bin/`