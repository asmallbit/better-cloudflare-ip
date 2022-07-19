#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

if [ "$1" = 'f' -o $# -lt 1 ]; then
    unamestr=$(uname)
    if [ "$unamestr" = 'Linux' ]; then
        export $(grep -v '^#' .format_env | xargs -d '\n')
    elif [ "$unamestr" = 'FreeBSD' ]; then
        export $(grep -v '^#' .format_env | xargs -0)
    fi
fi

./cf.sh
