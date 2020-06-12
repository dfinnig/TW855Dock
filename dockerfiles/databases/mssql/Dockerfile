FROM ubuntu:16.04 as builder
ARG PLATFORM_VERSION
ARG PLATFORM_ARCHIVE
COPY staging/${PLATFORM_ARCHIVE} /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && unzip -j "/tmp/${PLATFORM_ARCHIVE}" "install/*" -d "/tmp/install" \
    && echo "${PLATFORM_VERSION}" > /tmp/install/platform.version

FROM microsoft/mssql-server-linux:2017-latest

ARG TWX_DATABASE_PASSWORD
ARG TWX_DATABASE_USERNAME
ARG TWX_DATABASE_SCHEMA
ARG SA_PASSWORD
ENV TWX_DATABASE_PASSWORD=${TWX_DATABASE_PASSWORD} \
    TWX_DATABASE_USERNAME=${TWX_DATABASE_USERNAME} \
    TWX_DATABASE_SCHEMA=${TWX_DATABASE_SCHEMA} \
    SA_PASSWORD=${SA_PASSWORD}

COPY imageFiles/ /
COPY --from=builder /tmp/install /tmp/install/.

ENV PATH "/opt/mssql-tools/bin:${PATH}"

RUN if [ -z "${TWX_DATABASE_PASSWORD}" ] || [ -z "${TWX_DATABASE_USERNAME}" ] || [ -z "${TWX_DATABASE_SCHEMA}" ] || [ -z "${SA_PASSWORD}" ]; then echo "ERROR: You must provide a User, Password, and Schema for ThingWorx and SA user password with the following Environment Variables: "; echo "TWX_DATABASE_PASSWORD, TWX_DATABASE_USERNAME, TWX_DATABASE_SCHEMA, SA_PASSWORD"; exit 1; fi && \
    export ACCEPT_EULA=y && \
    (/opt/mssql/bin/sqlservr &) && \
    (until sqlcmd -U SA -P "${SA_PASSWORD}" -h -1 -Q "set nocount on; select serverproperty('ServerName')" | grep -w "${HOSTNAME}"; do echo "waiting for db to start..."; sleep 1; done) && \
    echo "Creating database user '${TWX_DATABASE_USERNAME}'" && \
    sqlcmd -U SA -P "${SA_PASSWORD}" -Q "create login ${TWX_DATABASE_USERNAME} with password = '${TWX_DATABASE_PASSWORD}', check_policy=off" && \
    cd /tmp/install && \
    echo "Assigning execute permission to database setup scripts" && \
    chmod +x thingworxMssqlDBSetup.sh && \
    chmod +x thingworxMssqlSchemaSetup.sh && \
    echo "Creating database '${TWX_DATABASE_SCHEMA}'" && \
    ./thingworxMssqlDBSetup.sh -h localhost -p 1433 -a SA -r "${SA_PASSWORD}" -l "${TWX_DATABASE_USERNAME}" -d "${TWX_DATABASE_SCHEMA}" -u "${TWX_DATABASE_USERNAME}" -s "${TWX_DATABASE_SCHEMA}" && \
    ./thingworxMssqlSchemaSetup.sh -h localhost -p 1433 -l "${TWX_DATABASE_USERNAME}" -r "${TWX_DATABASE_PASSWORD}" -d "${TWX_DATABASE_SCHEMA}" -o all && \
    echo "Assigning '${TWX_DATABASE_USERNAME}' user default database of '${TWX_DATABASE_SCHEMA}'" && \
    sqlcmd -U SA -P "${SA_PASSWORD}" -Q "alter login ${TWX_DATABASE_USERNAME} with default_database = ${TWX_DATABASE_SCHEMA}"

ENTRYPOINT ["/docker-entrypoint.sh"]
