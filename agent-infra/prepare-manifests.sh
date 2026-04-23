#!/bin/bash
TEMPLATE_PATH=$1
UID_SUFFIX=$2

if [ -z "$TEMPLATE_PATH" ] || [ -z "$UID_SUFFIX" ]; then
  echo "Usage: $0 <template_path> <uid_suffix>"
  exit 1
fi

FULL_NAME=$(basename "$TEMPLATE_PATH")
SHORT_NAME="$FULL_NAME"
if [ -f "${TEMPLATE_PATH}/.short_name" ]; then
  SHORT_NAME=$(cat "${TEMPLATE_PATH}/.short_name")
fi

echo "Suffixing manifests for $FULL_NAME (Short: $SHORT_NAME) with $UID_SUFFIX"

find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/${FULL_NAME}/${FULL_NAME}-${UID_SUFFIX}/g" {} +

if [ "$SHORT_NAME" != "$FULL_NAME" ]; then
  find "${TEMPLATE_PATH}/config-connector"* -type f -name "*.yaml" -exec sed -i "s/${SHORT_NAME}/${SHORT_NAME}-${UID_SUFFIX}/g" {} +
fi
