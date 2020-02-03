function configure_jdk {
	JAVA_HOME=/usr/lib/jvm/${JAVA_VERSION}
	PATH=/usr/lib/jvm/${JAVA_VERSION}/bin/:${PATH}
}

function customize_aliases {
	alias la="ls -la --group-directories-first"
}

function customize_prompt {
	PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\${PWD}\[\e[0m\] \\n\$ "
}

configure_jdk
customize_aliases
customize_prompt