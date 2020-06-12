ARG TAG_VERSION
FROM ubuntu:16.04 as builder

ARG PLATFORM_VERSION
ARG PLATFORM_ARCHIVE
COPY staging/${PLATFORM_ARCHIVE} /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && unzip "/tmp/${PLATFORM_ARCHIVE}" \
    && unzip -o -d Thingworx Thingworx.war


FROM thingworx/tw-platform-base:${TAG_VERSION}

COPY --from=builder /Thingworx ${CATALINA_HOME}/webapps/Thingworx/.
COPY imageFiles/ /
