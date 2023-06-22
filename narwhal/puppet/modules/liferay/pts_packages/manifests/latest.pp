class pts_packages::latest {

	package {
		[
		'acpid',
		'augeas-lenses',
		'base-files',
		'bash',
		'bash-completion',
		'bc',
		'binutils',
		'bsdmainutils',
		'bsdutils',
		'bzip2',
		'ca-certificates',
		'colordiff',
		'colortail',
		'cpio',
		'curl',
		'dbus',
		'debconf',
		'distro-info-data',
		'dpkg',
		'dstat',
		'ethtool',
		'file',
		'gawk',
		'git',
		'haveged',
		'host',
		'htop',
		'iotop',
		'iptables',
		'iputils-ping',
		'less',
		'lsb-release',
		'mc',
		'mtr-tiny',
		'net-tools',
		'netplan.io',
		'ngrep',
		'openssl',
		'passwd',
		'procps',
		'rsync',
		'strace',
		'sysstat',
		'systemd',
		'systemd-sysv',
		'tar',
		'telnet',
		'tmux',
		'ubuntu-keyring',
		'udev',
		'util-linux',
		'virt-what',
		]:
			ensure => latest,
			schedule => daily,
	}

	if $facts['virtual'] != 'lxc' {

		package { [
			'kpartx',
			'linux-firmware',
			'linux-image-generic-hwe-22.04',
			'linux-tools-common',
			'linux-tools-generic',
			]:
				ensure => latest,
				schedule => daily,
		}

	}

}
