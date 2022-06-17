# `lxc-static-resources` Docker Container

Base image used by Unified Static Liferay LXC extensions. The usage of this image is automated. However, the contract is to mount resources and/or [Caddyfile](https://caddyserver.com/docs/) fragments for the Caddy server (a micro HTTP server) to process.

The following is the `Dockerfile` that will be provided with LXC extensions:

```Dockerfile
FROM liferay/lxc-static-resources:latest

COPY static/ /resources/
```

This instructs that the files in `static/` be copied to the Caddy web server.
