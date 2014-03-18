#!/bin/bash
# Extracts a variable fron Config.h for use in scripts.

set -e

VARNAME=$1

if [ "$VARNAME" == "" ]; then
  echo "Usage: $0 VARNAME" >&2
  exit 1
fi

BASEDIR=$(dirname $0)
# Broken into 2 steps so we can fail fast if either fails.
LINE=$(grep $VARNAME $BASEDIR/../NovaCamera/Config.h)
echo "$LINE" | awk '{gsub("[\"@]", ""); print $3}'
