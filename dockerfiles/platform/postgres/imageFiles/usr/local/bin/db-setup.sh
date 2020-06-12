#!/bin/bash

export DATABASE_ADMIN_LOGIN="${DATABASE_ADMIN_USERNAME}"
export TWX_DATABASE_LOGIN="${TWX_DATABASE_USERNAME}"

if [ "${IS_AZURE_POSTGRES}" == "true" ]; then
  export DATABASE_ADMIN_LOGIN="${DATABASE_ADMIN_USERNAME}@${DATABASE_HOST}"
  export TWX_DATABASE_LOGIN="${TWX_DATABASE_USERNAME}@${DATABASE_HOST}"
  # TODO: The following exists until there is specific support for Azure Postgresql
  export IS_RDS="yes"
fi

export PGPASSFILE=".pgpass"
cat > "${PGPASSFILE}" <<EOF
*:*:${TWX_DATABASE_SCHEMA}:${TWX_DATABASE_LOGIN}:${TWX_DATABASE_PASSWORD}
EOF

chmod 600 "${PGPASSFILE}"

if [ -n "${DATABASE_ADMIN_PASSWORD}" ]; then
  cat >> "${PGPASSFILE}" <<EOF
*:*:${DATABASE_ADMIN_SCHEMA}:${DATABASE_ADMIN_LOGIN}:${DATABASE_ADMIN_PASSWORD}
EOF
  echo "Checking for database user ${TWX_DATABASE_USERNAME}..."
  twx_user_count=$(psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" \
                        -U "${TWX_DATABASE_LOGIN}" \
                        -v ON_ERROR_STOP=1 \
                        -tAc "SELECT count(*) FROM pg_roles WHERE rolname='${TWX_DATABASE_USERNAME}'")
  if [ "${twx_user_count}" != 1 ]; then
    echo "User ${TWX_DATABASE_USERNAME} does not exist. Creating..."
    psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${DATABASE_ADMIN_SCHEMA}" \
         -U "${DATABASE_ADMIN_LOGIN}" -v ON_ERROR_STOP=1 \
         -tAc "CREATE USER ${TWX_DATABASE_USERNAME} WITH PASSWORD '${TWX_DATABASE_PASSWORD}';"
  else
    echo "User ${TWX_DATABASE_USER} already exists."
  fi

  echo "Checking for database ${TWX_DATABASE_SCHEMA}..."
  if ! psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" -U "${TWX_DATABASE_LOGIN}" -c ""; then
    echo "Database ${TWX_DATABASE_SCHEMA} does not exist. Creating..."
    if [ "${IS_RDS}" != "yes" ]; then
      echo "NOT an RDS Instance"
      if [ -z "${TABLESPACE_LOCATION}" ]; then
        echo "ERROR: TABLESPACE_LOCATION must be set in the environment."
        exit 1
      fi
      psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${DATABASE_ADMIN_SCHEMA}" \
           -U "${DATABASE_ADMIN_LOGIN}" \
           -v database="${TWX_DATABASE_SCHEMA}" -v username="${TWX_DATABASE_USERNAME}" \
           -v tablespace="${TWX_DATABASE_SCHEMA}" -v tablespace_location="${TABLESPACE_LOCATION}" \
           -v ON_ERROR_STOP=1 \
           -f "${DBSCRIPT_DIR}/thingworx-database-setup.sql"
    else
      echo "IS an RDS Instance"
      psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${DATABASE_ADMIN_SCHEMA}" \
           -U "${DATABASE_ADMIN_LOGIN}" \
           -v database="${TWX_DATABASE_SCHEMA}" -v username="${TWX_DATABASE_USERNAME}" \
           -v adminusername="${DATABASE_ADMIN_USERNAME}" -v ON_ERROR_STOP=1 \
           -f "${DBSCRIPT_DIR}/thingworx-rds-database-setup.sql"
    fi

    echo "Installing model schema..."
    psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" \
         -U "${TWX_DATABASE_LOGIN}" \
         -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" \
         -v ON_ERROR_STOP=1 \
         -f "${DBSCRIPT_DIR}/thingworx-model-schema.sql"

    echo "Installing data schema..."
    psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" \
         -U "${TWX_DATABASE_LOGIN}" \
         -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" \
         -v ON_ERROR_STOP=1 \
         -f "${DBSCRIPT_DIR}/thingworx-data-schema.sql"

    echo "Installing property schema..."
    psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" \
         -U "${TWX_DATABASE_LOGIN}" \
         -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" \
         -v ON_ERROR_STOP=1 \
         -f "${DBSCRIPT_DIR}/thingworx-property-schema.sql"

    echo "Installing grants schema..."
    psql -h "${DATABASE_HOST}" -p "${DATABASE_PORT}" -d "${TWX_DATABASE_SCHEMA}" \
         -U "${TWX_DATABASE_LOGIN}" \
         -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" \
         -v ON_ERROR_STOP=1 \
         -f "${DBSCRIPT_DIR}/thingworx-grants-schema.sql"
  else
      echo "Database ${TWX_DATABASE_SCHEMA} already exists."
  fi
else
  echo "Not checking for database user/schema existence, because database admin credentials"
  echo "(DATABASE_ADMIN_USERNAME/DATABASE_ADMIN_PASSWOWRD) are not set."
fi

rm "${PGPASSFILE}"
