# Quick start guide

## single_server.yml
- Add `teleport-proxy` and `teleport-agent-test` configs/<ENV>.yml

## Setup teleport service
- Create `configs/<env>.-github.yml` from the template file

### Build & run
```bash
# build & run
$ orca all; orca up
```
### Enter the container
```bash
$ orca ssh teleport-proxy

# Setup GitHub connector and create token that can be used by the node to join
teleport-proxy$ teleport_init.sh

```
- After this the `teleport-agent-test` docker container should be able to find and use `tokent.txt` and start the service successfully.


## install teleport on the client machine
```bash
wget https://apt.releases.teleport.dev/gpg -O /etc/apt/teleport-archive-keyring.asc
echo "deb [signed-by=/etc/apt/teleport-archive-keyring.asc] https://apt.releases.teleport.dev/ubuntu jammy stable/v12" > /etc/apt/sources.list.d/teleport.list
apt update && apt install teleport
```

## Claim tsh session ticket

```bash
# logout for sure
$ tsh logout --proxy localhost --login tomposmiko --insecure localhost

# login
$ tsh login --proxy localhost --login tomposmiko --insecure localhost
WARNING: You are using insecure connection to Teleport proxy https://localhost:3080
If browser window does not open automatically, open it by clicking on the link:
 http://127.0.0.1:40897/fc55fefb-cbe2-4745-8da9-3ffc27e2c81d
> Profile URL:        https://localhost:3080
  Logged in as:       tomposmiko
  Cluster:            localhost
  Roles:              access, editor, host-certifier
  Logins:             tomposmiko, -teleport-internal-join
  Kubernetes:         enabled
  Valid until:        2023-02-15 10:27:13 +0100 CET [valid for 12h0m0s]
  Extensions:         permit-agent-forwarding, permit-port-forwarding, permit-pty, private-key-policy
```

## Add backend node to the cluster
### Create token on the proxy

token is created via `teleport_init.sh

### Join the backend node to the cluster after copying token.txt to the node

```bash
# Done in docker's entrypoint.sh
$ teleport start --roles=node --token=/token.txt --auth-server=teleport-proxy
```

## tsh ssh shell access to a remote backend server
- hostname is: `<hiostname>-<clustername>`, as it is added on the proxy

```bash
tsh ssh tomposmiko@teleport-agent-test-localhost
```

## Dashboard login

https://localhost:3080/