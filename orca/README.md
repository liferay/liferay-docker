# Managed DXP - Orca

Simple default configuration to deploy Liferay DXP Clusters on Linux servers, only using simple tools.

## Host requirements

1. must have `amd64` CPU
    * The host must run on an `amd64` architecture (Intel). `arm64` is currently not supported, so you won't be able to use the tool for example on computers with M1 chips from Apple or various arm-based AWS instances.
    * The support for `arm64` may be added in the future, but it's currently not a priority.

## OS requirements

1. must be _Ubuntu_
    * Only Ubuntu (20.04+, 22.04+) is currently supported. If you need to run in another OS, please use a VM with the proper Ubuntu version inside.

2. Create a new mounted filesystem (xfs recommended) to `/opt/gluster-data/gv0`

    * Execute the following commands on all servers:

        ```
        $ curl https://raw.githubusercontent.com/liferay/liferay-docker/master/orca/scripts/install_orca.sh -o /tmp/install_orca.sh
        $ . /tmp/install_orca.sh
        ```
    * Then log in to the first server and execute the following:

        ```
        $ gluster peer probe <host-name of the second server>
        $ gluster peer probe <host-name of the third server>
        $ ...
        $ gluster volume create gv0 replica 3 <vm-1>:/opt/gluster-data/gv0/ <vm-2>:/opt/gluster-data/gv0/ <vm-3>:/opt/gluster-data/gv0/
        $ gluster volume start gv0
        $ gluster volume info
        $ mount /opt/liferay/shared-volume
        ```
