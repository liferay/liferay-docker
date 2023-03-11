class pts_packages::absent {

  package { [
    'apt-xapian-index',
    'aptitude',
    'aptitude-common',
    'cloud-init',
    'ed',
    'fwupd',
    'landscape-client',
    'laptop-detect',
    'libmm-glib0',
    'libpam-cracklib',
    'modemmanager',
    'nscd',
    'open-vm-tools',
    'packagekit',
    'pollinate',
    'popularity-contest',
    'ppp',
    'pppconfig',
    'pppoeconf',
    'python-debian',
    'ubuntu-advantage-tools',
    'ufw',
    'unattended-upgrades',
    'wireless-tools',
    'wpasupplicant',
    ]:
    ensure   => purged,
    schedule => daily2
  }

}
