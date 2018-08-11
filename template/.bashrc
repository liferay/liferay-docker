function customize_aliases {
	alias la="ls -la --group-directories-first"
}

function customize_prompt {
	PS1="\[\e]0;\w\a\]\n\[\e[32m\]\u@\h \[\e[33m\]\${PWD}\[\e[0m\] \\n\$ "
}

customize_aliases
customize_prompt