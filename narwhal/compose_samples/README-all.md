# Preperation

## Copy license and replace IPs

Add Liferay DXP license to the `license.xml` file and edit the IP addresses of the servers in the env.servers file.

```
./copy_license.sh
./replace_ips.sh
```

## Deploy configuration

Copy the server-<number> directory to the servers respectively. Review the docker-compose files and add the missing details (e.g. passwords).

## Prepare the server environment

Adjust the OS requirements:

```
./pre.sh
```

# Start services

```
docker compose up

```
