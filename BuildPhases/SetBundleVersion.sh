#!/bin/sh
# -----------------------------------------------------------------------------
# This script generates two types of versions for your iOS project:
#
# 1. A dotted version string (VERSION_STRING_BASE) in the format:
#    year.dayOfYear.hourMinute (e.g., 2025.41.1844)
#    - Optionally loaded from the environment variable VERSION_STRING_BASE.
#
# 2. An integer version code (VERSION_CODE) formatted as:
#    year (2 digits) + day-of-year (3 digits) + hour (2 digits) + minute (2 digits)
#    - Optionally loaded from the environment variable VERSION_CODE.
#
# A static suffix is appended to the version string:
#    - Default is "-local", or use the environment variable VERSION_STRING_SUFFIX.
#
# The script then sets:
#   CFBundleShortVersionString	= VERSION_STRING_BASE + VERSION_STRING_SUFFIX
#   CFBundleVersion				= VERSION_CODE
#
# INFOPLIST_FILE must be set to the path of your Info.plist file.
# -----------------------------------------------------------------------------

# Generate all date components once.
read FULL_YEAR SHORT_YEAR DAY_OF_YEAR TIME <<< $(date +"%Y %y %j %H%M")

# Convert the padded DAY_OF_YEAR to non-padded for VERSION_STRING_BASE,
# "10#" forces base 10 because leading 0 would be otherwise treated as octal.
NONPADDED_DAY_OF_YEAR=$((10#$DAY_OF_YEAR))

# Generate VERSION_STRING_BASE.
VERSION_STRING_BASE="${FULL_YEAR}.${NONPADDED_DAY_OF_YEAR}.${TIME}"

# Until CI/CD pipeline is working, suffix will be empty to avoid problems with production builds
# VERSION_STRING_SUFFIX="-local"
VERSION_STRING_SUFFIX=""

# Compose the full version string.
FULL_VERSION_STRING="${VERSION_STRING_BASE}${VERSION_STRING_SUFFIX}"

# Generate VERSION_CODE.
VERSION_CODE="${SHORT_YEAR}${DAY_OF_YEAR}${TIME}"

echo "ℹ️ Full Version String (CFBundleShortVersionString): $FULL_VERSION_STRING"
echo "ℹ️ Using VERSION_CODE (CFBundleVersion): $VERSION_CODE"

# Update build number in created binary's Info.plist
if [ -f "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" ]; then
	echo "ℹ️ Updating Info.plist at ${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
	
	if /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_CODE" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}" && \
	   /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $FULL_VERSION_STRING" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"; then
		echo "✅ Binary Info.plist updated successfully"
	else
		echo "❌ Error: Failed to update Binary Info.plist."
		exit 1
	fi
else
	echo "❌ Error: TARGET_BUILD_DIR/INFOPLIST_PATH environment variable is not set"
	exit 2
fi

# Update build number in original plist so it is consistent
if [ -n "$INFOPLIST_FILE" ]; then
	echo "ℹ️ Updating Info.plist at ${INFOPLIST_FILE}"

	if /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION_CODE" "$INFOPLIST_FILE" && \
	   /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $FULL_VERSION_STRING" "$INFOPLIST_FILE"; then
		echo "✅ Original Info.plist updated successfully"
	else
		echo "❌ Error: Failed to update Original Info.plist."
		exit 3
	fi
else
	echo "❌ Error: INFOPLIST_FILE environment variable is not set"
	exit 4
fi
