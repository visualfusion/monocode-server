#!/usr/bin/env bash
if [ "$1" == "-f" ] || [ "$2" == "-f" ]; then
    sudo supervisorctl tail -f monocode-host stderr
else
    sudo supervisorctl tail -50 monocode-host stderr
fi
