# Preperation

## Copy license

Add Liferay license to the `license.xml` file and copy to their build scripts respectively:

```
./copy-license.sh
```

## Deploy code

Copy the server-<number> directory to the servers respectively.

## Prepare the server environment

Adjust the OS requirements:

```
./pre.sh
```


# Build images

```
./compose.sh build
```

# Fire up the services

```
./compose.sh up

```
