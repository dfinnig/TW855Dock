#!/bin/bash

set -e
# export all variables to be sure they are visible to docker-helper
set -a

for default in $(cat /usr/local/etc/default-vars-base /usr/local/etc/default-vars); do
  var=$(echo -n "${default}" | grep -oP '(?<=DEFAULT_)[^=]+')
  default_val=$(echo -n "${default}" | cut -d = -f 2-)
  env_val=$(eval echo \$${var})
  if [ -z "${env_val}" ]; then
    if [ "${DOCKER_DEBUG}" == "true" ]; then
        echo "Setting ${var} to default value: ${default_val}"
    fi
    eval export ${var}="${default_val}"
  fi
done

if [ -d /tmp/tw-db-scripts -a -f /usr/local/bin/db-setup.sh ]; then
  export DBSCRIPT_DIR="/tmp/tw-db-scripts"
  chmod +x /usr/local/bin/db-setup.sh
  /usr/local/bin/db-setup.sh
fi

export THINGWORX_PLATFORM_SETTINGS="/ThingworxPlatform"
export THINGWORX_STORAGE="/ThingworxStorage"
export THINGWORX_BACKUP_STORAGE="/ThingworxBackupStorage"
mkdir -p "${THINGWORX_PLATFORM_SETTINGS}" "${THINGWORX_STORAGE}" "${THINGWORX_BACKUP_STORAGE}"

echo "Generating configuration files with template-processor"
/opt/template-processor/bin/template-processor run-commands

# merge platform settings and put in right location
(cd /@var_dirs@/THINGWORX_PLATFORM_SETTINGS
echo "Merging reference conf with overrides"
jq -s '.[0] * .[1] * .[2] * .[3]' \
   platform-settings-reference.json \
   platform-settings-overrides.json \
   platform-settings-overrides-base.json \
   platform-settings-customer-overrides.json \
   > platform-settings.json

if [ "${DOCKER_DEBUG}" == "true" ]; then
    echo "Rendered platform-settings.json:"
    cat platform-settings.json
fi
)

# move files in variablized directories to their final location
install-var-dirs.sh

if [ -n "${TWX_KEYSTORE_PASSWORD}" ]; then
    if [ -f "${THINGWORX_PLATFORM_SETTINGS}/keystore-password" ]; then
        if [ "x${TWX_KEYSTORE_PASSWORD}" != "x$(cat ${THINGWORX_PLATFORM_SETTINGS}/keystore-password)" ]; then
            echo "ERROR: Attempting to set TWX_KEYSTORE_PASSWORD in ${THINGWORX_PLATFORM_SETTINGS}/keystore-password. File already exists and contains a different value."
            echo "ERROR: If this is an existing installation, do not override this password as the platform will no longer work."
            exit 1
        fi
    else
        echo "Setting ${THINGWORX_PLATFORM_SETTINGS}/keystore-password to provided password."
        echo "${TWX_KEYSTORE_PASSWORD}" > "${THINGWORX_PLATFORM_SETTINGS}/keystore-password"
    fi
fi

if [ "${ENCRYPT_CREDENTIALS}" == "true" ]; then
    echo "Encrypting Platform Settings Credentials"
    (
      if [ "${DB_TYPE}" == "postgres" ] || [ "${DB_TYPE}" == "mssql" || [ "${DB_TYPE}" == "azuresql" ]; then
          /opt/security-tool/bin/security-common-cli /opt/keystore.conf set encrypt.db.password "${TWX_DATABASE_PASSWORD}"
          echo "Security Tool ($?) -- Stored DB Password"
      fi
      if [ "${LS_PASSWORD}" != "" ]; then
          /opt/security-tool/bin/security-common-cli /opt/keystore.conf set encrypt.licensing.password "${LS_PASSWORD}"
          echo "Security Tool ($?) -- Stored License Password"
      fi
      if [ "${LS_PROXY_PASSWORD}" != "" ]; then
          /opt/security-tool/bin/security-common-cli /opt/keystore.conf set encrypt.proxy.password "${LS_PROXY_PASSWORD}"
          echo "Security Tool ($?) -- Stored License Proxy Password"
      fi
      if [ "${PROPERTY_TRANSFORM_RABBITMQ_PASSWORD}" != "" ]; then
          /opt/security-tool/bin/security-common-cli /opt/keystore.conf set encrypt.propertytransform.password "${PROPERTY_TRANSFORM_RABBITMQ_PASSWORD}"
          echo "Security Tool ($?) -- Stored Property Transform RabbitMQ Password"
      fi
      if [ "${SOLUTION_CENTRAL_KEYSTORE_PASS}" != "" ]; then
          /opt/security-tool/bin/security-common-cli /opt/keystore.conf set encrypt.sc.keystore.password "${SOLUTION_CENTRAL_KEYSTORE_PASS}"
          echo "Security Tool ($?) -- Stored Solution Central Password"
      fi
    )
fi

# Remove the security tool after configuration complete if it exists
[ -d "/opt/security-tool" ] && rm -rf /opt/security-tool

chown -R "${APP_USER}:${APP_USER}" "${THINGWORX_STORAGE}"
chown -R "${APP_USER}:${APP_USER}" "${THINGWORX_PLATFORM_SETTINGS}"
chown -R "${APP_USER}:${APP_USER}" "${THINGWORX_BACKUP_STORAGE}"
chown -R "${APP_USER}:${APP_USER}" "${CATALINA_HOME}"

# workaround for https://github.com/docker/docker/issues/9547
sync

exec gosu "${APP_USER}" "${CATALINA_HOME}/bin/catalina.sh" "${@}"
