#!/bin/bash

if [ -z "${TWX_DATABASE_PASSWORD}" ] || [ -z "${TWX_DATABASE_USERNAME}" ] || [ -z "${TWX_DATABASE_SCHEMA}" ]; then
    echo "ERROR: You must provide a User, Password, and Schema for ThingWorx with the following Environment Variables: "
    echo "TWX_DATABASE_PASSWORD, TWX_DATABASE_USERNAME, TWX_DATABASE_SCHEMA"
    exit 1
fi

if [ -z "${CUSTOM_CONF}" ]; then
    total_mem=$(free -g | grep "Mem:" | awk '{ print $2 }')
    half_mem=$(expr ${total_mem} / 2)
    quarter_mem=$(expr ${total_mem} / 4)

    effective_cache_size=${half_mem}GB
    shared_buffers=${quarter_mem}GB
    max_wal_size=480MB
    checkpoint_completion_target=0.5
    work_mem=32MB
    ssl_renegotiation_limit=0
    max_connections=200

    if [ "${total_mem}" -ge "58" ]; then
        max_wal_size=7680MB
        checkpoint_completion_target=0.9
        max_connections=700
    elif [ "${total_mem}" -le "57" -a "${total_mem}" -ge "46" ]; then
        max_wal_size=3840MB
        checkpoint_completion_target=0.8
        max_connections=600
    elif [ "${total_mem}" -le "45" -a "${total_mem}" -ge "34" ]; then
        max_wal_size=1920MB
        checkpoint_completion_target=0.7
        max_connections=500
    elif [ "${total_mem}" -le "33" -a "${total_mem}" -ge "22" ]; then
        max_wal_size=960MB
        checkpoint_completion_target=0.6
        max_connections=400
    elif [ "${total_mem}" -le "21" -a "${total_mem}" -ge "10" ]; then
        max_wal_size=480MB
        max_connections=300
    fi
else
    IFS=';'
    for pg_setting in ${CUSTOM_CONF}; do
        export ${pg_setting}
    done
    unset IFS
fi

echo
echo "Configuring ${PGDATA}/postgresql.conf"
echo

cat >> "${PGDATA}/postgresql.conf" <<EOF
effective_cache_size = ${effective_cache_size}
shared_buffers = ${shared_buffers}
max_wal_size = ${max_wal_size}
checkpoint_completion_target = ${checkpoint_completion_target}
work_mem = ${work_mem}
ssl_renegotiation_limit = ${ssl_renegotiation_limit}
EOF

sed -i "/.*max_connections = \d*/c max_connections = ${max_connections}" ${PGDATA}/postgresql.conf

echo
echo "Loading Thingworx Database structure"
echo

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "CREATE USER ${TWX_DATABASE_USERNAME} WITH PASSWORD '${TWX_DATABASE_PASSWORD}';"

psql -v database="${TWX_DATABASE_SCHEMA}" -v username="${TWX_DATABASE_USERNAME}" -v tablespace="${TWX_DATABASE_SCHEMA}" -v tablespace_location='/ThingworxPostgresqlStorage' -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f /tmp/install/thingworx-database-setup.sql
psql -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" -v ON_ERROR_STOP=1 --username "${TWX_DATABASE_USERNAME}" --dbname "${TWX_DATABASE_SCHEMA}" -f /tmp/install/thingworx-model-schema.sql
psql -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" -v ON_ERROR_STOP=1 --username "${TWX_DATABASE_USERNAME}" --dbname "${TWX_DATABASE_SCHEMA}" -f /tmp/install/thingworx-data-schema.sql
psql -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" -v ON_ERROR_STOP=1 --username "${TWX_DATABASE_USERNAME}" --dbname "${TWX_DATABASE_SCHEMA}" -f /tmp/install/thingworx-property-schema.sql
psql -v user_name="${TWX_DATABASE_USERNAME}" -v searchPath="${TWX_DATABASE_SCHEMA}" -v ON_ERROR_STOP=1 --username "${TWX_DATABASE_USERNAME}" --dbname "${TWX_DATABASE_SCHEMA}" -f /tmp/install/thingworx-grants-schema.sql


if [ -n "${CREATE_DBS}" ]; then
    echo
    echo "Loading additional databases"
    echo

    IFS=","
    for db_to_create in ${CREATE_DBS}; do
        echo "Creating: ${db_to_create}"
        # Use capitalized names for db user and pass environment variables,
        # see https://github.com/mesosphere/marathon/issues/4911 for details.
        # Also sanitizing the given db name accordingly, make them uppercase and replace non 'A-Z0-9_' with '_'.
        # E.g.: For "grafana-db1", use GRAFANA_DB1_USER and GRAFANA_DB1_PASS environment variables.
        dbuser=$(echo -n "$db_to_create" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_')_USER
        dbpass=$(echo -n "$db_to_create" | tr '[:lower:]' '[:upper:]' | tr -c 'A-Z0-9_' '_')_PASS
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "CREATE USER ${!dbuser:-$db_to_create} WITH PASSWORD '${!dbpass:-$db_to_create}';"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "CREATE DATABASE ${db_to_create} OWNER ${!dbuser:-$db_to_create};"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "GRANT ALL PRIVILEGES ON DATABASE ${db_to_create} to ${!dbuser:-$db_to_create};"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "ALTER DATABASE ${db_to_create} OWNER to ${!dbuser:-$db_to_create};"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_to_create" -tAc "REVOKE ALL ON schema public FROM public;"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_to_create" -tAc "GRANT ALL ON schema public TO ${!dbuser:-$db_to_create};"
    done
    unset IFS
fi
