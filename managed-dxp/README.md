# Managed DXP - Orca

Simple default configuration to deploy Liferay DXP Clusters on Linux servers, only using simple tools.

## Ubuntu reqirements

Create a new mounted filesystem (xfs recommended) to /opt/gluster-data

Execute the following commands on all servers:

    $ apt-get --yes install docker-compose git glusterfs-server pwgen
    $ systemctl enable glusterd
    $ systemctl start glusterd 
    $ mkdir -p /opt/gluster-data/gv0
    $ mkdir -p /opt/liferay/shared-volume
    $ echo "$(hostname):/gv0 /opt/liferay/shared-volume glusterfs defaults 0 0" >> /etc/fstab
    $ cd /opt/liferay
    $ curl https://raw.githubusercontent.com/liferay/liferay-docker/master/managed-dxp/install_orca.sh -o /tmp/install_orca.sh
    $ . /tmp/install_orca.sh
    $ snap install yq

Then log in to the first server and execute the following:

    $ gluster peer probe <host-name of the second server>
    $ gluster peer probe <host-name of the third server>
    $ ...
    $ gluster volume create gv0 replica 3 <vm-1>:/opt/gluster-data/gv0/ <vm-2>:/opt/gluster-data/gv0/ <vm-3>:/opt/gluster-data/gv0/
    $ gluster volume start gv0
    $ gluster volume info
    $ mount /opt/liferay/shared-volume
