ARG TAG_VERSION
FROM ubuntu:16.04 as builder
ARG PLATFORM_VERSION
ARG PLATFORM_ARCHIVE
ARG SQLDRIVER_VERSION
ARG SQLDRIVER_ARCHIVE
COPY staging/${PLATFORM_ARCHIVE} staging/${SQLDRIVER_ARCHIVE} /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && unzip "/tmp/${PLATFORM_ARCHIVE}" \
    && unzip -o -d Thingworx Thingworx.war \
    && tar -xvf /tmp/${SQLDRIVER_ARCHIVE} \
    && mv sqljdbc_6.0/enu/jre8/sqljdbc42.jar /tmp/sqljdbc42-${SQLDRIVER_VERSION}.jar


FROM thingworx/tw-platform-base:${TAG_VERSION}

COPY --from=builder /Thingworx ${CATALINA_HOME}/webapps/Thingworx/.
COPY --from=builder /tmp/sqljdbc42-*.jar ${CATALINA_HOME}/lib/.
COPY --from=builder /install /tmp/tw-db-scripts/.
COPY imageFiles/ /

RUN apt-get update \
    # ca-certificates is here so we can validate the cert at packages.microsoft.com
    && apt-get install -y --no-install-recommends apt-transport-https ca-certificates locales \
    && locale-gen en_US.utf8 && update-locale \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | tee /etc/apt/sources.list.d/msprod.list \
    && apt-get remove -y ca-certificates \
    && apt-get update && yes | apt-get install -y --no-install-recommends mssql-tools \
    && apt-get clean
