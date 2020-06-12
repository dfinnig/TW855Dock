FROM ubuntu:16.04 as builder
ARG PLATFORM_VERSION
ARG PLATFORM_ARCHIVE
COPY staging/${PLATFORM_ARCHIVE} /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && unzip -j "/tmp/${PLATFORM_ARCHIVE}" "install/*" -d "/tmp/install" \
    && echo "${PLATFORM_VERSION}" > /tmp/install/platform.version

FROM postgres:10.8

COPY imageFiles/ /
COPY --from=builder /tmp/install /tmp/install/.

RUN mkdir /ThingworxPostgresqlStorage \
    && chown postgres /ThingworxPostgresqlStorage

VOLUME /ThingworxPostgresqlStorage
