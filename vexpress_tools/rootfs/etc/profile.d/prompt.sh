#!/bin/sh
# Fancy dynamic PS1

if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\033[1;31m\]\u@\h\[\033[0m\]:\w# '
else
    PS1='\[\033[1;32m\]\u@\h\[\033[0m\]:\w$ '
fi
