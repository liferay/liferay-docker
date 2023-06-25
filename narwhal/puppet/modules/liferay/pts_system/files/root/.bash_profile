# MANAGED BY PUPPET, LOCAL CHANGES WILL BE OVERRIDDEN
# vim: set ft=bash:

alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias ls='ls --color=auto --show-control-chars -A -F'
alias pat='puppet agent -t'
alias pat='puppet agent -t'
alias pate='puppet agent -t --environment'
alias patn='puppet agent -t --noop'
alias patne='puppet agent -t --noop --noop --environment'
export COLOR_BLUE="\e[1;34m"
export COLOR_CYAN="\e[1;36m"
export COLOR_GREEN="\e[1;32m"
export COLOR_NOCOLOR="\e[00m"
export COLOR_PURPLE="\e[1;35m"
export COLOR_RED="\e[1;31m"
export EDITOR=vim
export HISTFILESIZE=100000
export HISTSIZE=100000
export HISTTIMEFORMAT="%y-%m-%d %T "
export LC_ALL=en_US.UTF-8
export PS1="\[${COLOR_CYAN}\]\h\[${COLOR_BLUE}\] \w # \[${COLOR_NOCOLOR}\]"
export VISUAL=vim

if [ -f ~/.bash_local ]
then
	# shellcheck disable=SC1090
	. ~/.bash_local
fi
