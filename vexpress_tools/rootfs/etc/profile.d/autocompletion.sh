#!/bin/sh
# Enable command completion if available

if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
