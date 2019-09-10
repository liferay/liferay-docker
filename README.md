# liferay-docker repository

## Building docker images
The `build_image.sh` is used to build the docker images. It takes one mandatory parameter, the URL of the Liferay Portal / DXP image (using Liferay's server URLs). For direct push to Docker Hub, the `push` command line argument should be added after the URL.

For Liferay DXP images, the `LIFERAY_DOCKER_LICENSE_CMD` needs to be set to generate the trial license. For testing purposes, it can be set to any URL and the image will be built without a license.

## Images
Images built with scripts in this repository will start Liferay DXP or Portal. The 8080 (tomcat http) and 11311 (Gogo shell telnet) ports are exposed.

Run the container with the option "-v $(pwd)/xyz123:/mnt/liferay" to bridge $(pwd)/xyz123 in the host operating system to /mnt/liferay on the container. Files in this directory will be used by the startup script to deploy changes on your instance. These are the subfolders which are processed:
 - `files`: File from this folder will be copied over to the Liferay home folder (/opt/liferay). Create a similar directory structure to override files deeper. (e.g. create xyz123/files/tomcat/conf/context.xml to override the file). These files are copied over before Liferay starts.
 - `scripts`: Files in /mnt/liferay/scripts will be executed, in alphabetical order, before Liferay DXP starts.
 - `deploy`: Copy files to $(pwd)/xyz123/deploy to deploy modules to Liferay DXP before startup and at runtime.

## Development on this repository
To speed up development, here are some tips:
 - To run the last built docker image run: ``docker run `docker images -q | head -n1` ``
 - To test changes to the entrypoint script without rebuilding, mount the `templates/scripts` folder from your `liferay-docker` repository to `/usr/local/bin`: `-v $PWD/template/scripts:/usr/local/bin/`