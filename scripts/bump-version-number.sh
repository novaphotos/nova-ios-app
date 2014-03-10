#!/bin/sh

PLISTBUDDY="/usr/libexec/PlistBuddy"
PLIST="NovaCamera/NovaCamera-Info.plist"

if [ "$1" = "" ]; then
	CURRENT_RELEASE_BRANCH=`git branch | grep '^*' | grep release | sed -e 's/.*release\///'`
	if [ "$CURRENT_RELEASE_BRANCH" = "" ]; then
		echo "Usage: $0 <version-number>"
		exit
	fi
	RELEASE=$CURRENT_RELEASE_BRANCH
else
	RELEASE=$1
fi

function bump {
	RELEASE=$1
	PLIST=$2
	$PLISTBUDDY -c "Set :CFBundleShortVersionString $RELEASE" $PLIST
	$PLISTBUDDY -c "Set :CFBundleVersion $RELEASE" $PLIST
	echo "Updated $PLIST versions to $RELEASE"
}

bump $RELEASE $PLIST

