#!/bin/bash

PATH="/opt/mssql-tools/bin:${PATH}"

if [ -z "${DATABASE_ADMIN_USERNAME}" ]; then
  DATABASE_ADMIN_USERNAME="SA"
fi

if [ -n "${DATABASE_ADMIN_PASSWORD}" ]; then
  echo "Checking for database user ${TWX_DATABASE_USERNAME}..."
  if sqlcmd -S "${DATABASE_HOST},${DATABASE_PORT}" \
            -U "${DATABASE_ADMIN_USERNAME}" -P "${DATABASE_ADMIN_PASSWORD}" -h -1 \
            -Q "set nocount on; select loginname from master.dbo.syslogins where name = '${TWX_DATABASE_USERNAME}'" | grep -w "${TWX_DATABASE_USERNAME}"; then
    echo "User ${TWX_DATABASE_USERNAME} already exists."
  else
    echo "User ${TWX_DATABASE_USERNAME} does not exist. Creating..."
    sqlcmd -S "${DATABASE_HOST},${DATABASE_PORT}" \
           -U "${DATABASE_ADMIN_USERNAME}" -P "${DATABASE_ADMIN_PASSWORD}" \
           -Q "create login ${TWX_DATABASE_USERNAME} with password = '${TWX_DATABASE_PASSWORD}'"
    created_db_user=y
  fi
  cd "${DBSCRIPT_DIR}"

  if sqlcmd -S "${DATABASE_HOST},${DATABASE_PORT}" \
            -U "${TWX_DATABASE_USERNAME}" -P "${TWX_DATABASE_PASSWORD}" -h -1 \
            -Q "set nocount on; select name from master.dbo.sysdatabases where name = '${TWX_DATABASE_SCHEMA}'" | grep -w "${TWX_DATABASE_SCHEMA}"; then
    echo "Database ${TWX_DATABASE_SCHEMA} already exists."
  else
    echo "Database ${TWX_DATABASE_SCHEMA} does not exist. Creating..."
    ./thingworxMssqlDBSetup.sh -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" \
                               -a "${DATABASE_ADMIN_USERNAME}" -r "${DATABASE_ADMIN_PASSWORD}" \
                               -l "${TWX_DATABASE_USERNAME}" -u "${TWX_DATABASE_USERNAME}" \
                               -d "${TWX_DATABASE_SCHEMA}" -s "${TWX_DATABASE_SCHEMA}"
    ./thingworxMssqlSchemaSetup.sh -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" \
                                   -l "${TWX_DATABASE_USERNAME}" -r "${TWX_DATABASE_PASSWORD}" \
                                   -d "${TWX_DATABASE_SCHEMA}" -o all
  fi

  if [ -n "${created_db_user}" ]; then
      sqlcmd -S "${DATABASE_HOST},${DATABASE_PORT}" \
             -U "${DATABASE_ADMIN_USERNAME}" -P "${DATABASE_ADMIN_PASSWORD}" \
             -Q "alter login thingworx with default_database = ${TWX_DATABASE_SCHEMA}"
  fi
else
  echo "Not checking for database user/schema existence, because database admin credentials"
  echo "(DATABASE_ADMIN_USERNAME/DATABASE_ADMIN_PASSWOWRD) are not set."
fi
