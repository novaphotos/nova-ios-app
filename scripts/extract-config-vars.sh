#!/bin/sh

TARGET_PLIST_FILE=$1

CONFIG_H="NovaCamera/Config.h"

echo "Running extract-config-vars.sh; cwd: `pwd`"

if [ ! -f $CONFIG_H ]; then
	echo "Unable to open file: $CONFIG_H"
	echo "Ensure this script is executed from the source root directory"
	exit 1
fi

AVIARY_KEY=`cat $CONFIG_H | grep AVIARY_KEY | sed -e 's/[^"]*"//' | sed -e 's/".*//'`
echo "AVIARY_KEY=$AVIARY_KEY"
export AVIARY_KEY

