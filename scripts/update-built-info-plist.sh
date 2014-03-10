#!/bin/sh

PLISTBUDDY="/usr/libexec/PlistBuddy"
PLIST=$1

echo "Retrieving API key"
. scripts/extract-config-vars.sh
echo "Got it"

echo "Setting Aviary-API-Key to '${AVIARY_KEY}' in $PLIST"
CMD="$PLISTBUDDY -c \"Set Aviary-API-Key ${AVIARY_KEY}\" $PLIST"
echo "cmd; $CMD"
$PLISTBUDDY -c "Set Aviary-API-Key ${AVIARY_KEY}" $PLIST

