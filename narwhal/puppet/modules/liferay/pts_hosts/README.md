# hosts

## Overview

A puppet module to manage the contents of hosts files.

## Module Description

This module can be used to manage the contents of the hosts file. In addition
to user supplies entries, it can also automatically create entries for the 
loopback interfaces (ipv4 and ipv6) as well.

## Setup

### What hosts affects

* This module will make changes to your hosts file - /etc/hosts for most
  operating systems.

### Beginning with hosts

Declare the class and add entries as follows:

```
class { '::hosts' : }

::hosts::add { '192.168.0.1' :
    fqdn    => 'router.mydomain.com',
    aliases => [ 'router' ]
}
```

## Usage

### Classes

Declare the class. There are a number of optional parameters whose defaults
are listed below:
```
class { '::hosts' :
    file        => '/etc/hosts',
    owner       => 'root',
    group       => 'root',
    mode        => '0644',
    localhost   => true,
    primary     => true,
    purge       => false,
}
```

#### Parameters within `hosts`:
* `file`: Optional. Path to hosts file. Default value varies depedning on Operating System.
* `owner`: Optional. User that has ownership of the hosts file. Defaults to root.
* `group`: Optional. Group that has group ownership of the hosts file. Defaults to root.
* `mode`: Optional. File permissions mode for the hosts file. Defaults to 0644.
* `localhost`: Optional. Add hosts file entries for localhost/loopback interfaces. Defaults to true.
* `primary`: Optional. Add host file entries for primary fqdn & hostname to primary IP Address. Defaults to true.
* `purge`: Optional. Remove unmanaged entries from the hosts file. Defaults to false.

### Types

Create hosts file entries as follows:
```
::hosts::add { '192.168.0.1' :
    fqdn    => 'router.mydomain.com',
    aliases => [ 'router' ],
}
```

#### Parameters with `hosts::add`:
* `fqdn`: Required. Fully qualified domain for the hosts file entry. You could use os plain hostname if need be.
* `aliases`: Optional. String or array containing aliases for the hosts file entry.

## Reference

### Public classes

* `hosts`: The main class used to interact with this module.

### Private classes

* `hosts::file`: Class to handle declare the file resource and set the ownership and permissions.
* `hosts::localhost`: Class to add localhost entries to the hosts file.
* `hosts::params`: Class to store default parameter values and determine OS specific values.
* `hosts::primary`: Class to add hosts file entries for the primary interface (::ipaddress -> ::fqdn/::hostname).

### Types

* `hosts::add`: Type to create hosts file entries.

## Limitations

This module has been made for (osfamily) Debian and RedHat (and their derivatives), however it should work fine on any
'nix. You may need to manually specify the path to the hosts file, and you will need sed.

## Development

Appreciate any suggestions on feature or code changes. Let me know if you want to contribute or collaborate.

