ARG TAG_VERSION
FROM ubuntu:16.04 as builder

ARG TOMCAT_VERSION
ARG TOMCAT_ARCHIVE
ARG LICENSE_FILE
ARG PLATFORM_SETTINGS_FILE
ARG TEMPLATE_PROCESSOR_ARCHIVE
ARG SECURITY_TOOL_ARCHIVE

COPY staging/ /tmp/
RUN cd /opt \
    && tar -xvf "/tmp/${TOMCAT_ARCHIVE}" \
    && mv "apache-tomcat-${TOMCAT_VERSION}" apache-tomcat \
    && echo "${TOMCAT_VERSION}" > apache-tomcat/tomcat.version \
    && rm -rvf apache-tomcat/webapps/* \
    && mkdir -p /opt/template-processor \
    && tar -xvzf "/tmp/${TEMPLATE_PROCESSOR_ARCHIVE}" -C "/opt/template-processor" --strip-components=1 \
    && mkdir -p /opt/security-tool \
    && tar -xvzf "/tmp/${SECURITY_TOOL_ARCHIVE}" -C "/opt/security-tool" --strip-components=1 \
    && mkdir -p "/@var_dirs@/THINGWORX_PLATFORM_SETTINGS" \
    && if [ -f "/tmp/${LICENSE_FILE}" ]; then mv "/tmp/${LICENSE_FILE}" "/@var_dirs@/THINGWORX_PLATFORM_SETTINGS/license.bin"; fi \
    && mv "/tmp/${PLATFORM_SETTINGS_FILE}" "/@var_dirs@/THINGWORX_PLATFORM_SETTINGS/platform-settings-reference.json"

FROM thingworx/base:${TAG_VERSION}

ENV CATALINA_HOME=/opt/apache-tomcat
ENV PATH=$CATALINA_HOME/bin:${PATH}
ENV INITIAL_HEAP=1
ENV MAX_HEAP=2
ENV ENABLE_SNI=false
ENV ENABLE_CONSOLE_OUTPUT=false

COPY --from=builder /opt/ /opt/.
COPY --from=builder /@var_dirs@/THINGWORX_PLATFORM_SETTINGS/ /@var_dirs@/THINGWORX_PLATFORM_SETTINGS/.

COPY imageFiles/ /

RUN apt-get update \
    # curl is here so that docker-compose can run a health check
    && apt-get install -y --no-install-recommends curl jq \
    && apt-get clean \
    && mkdir "${CATALINA_HOME}/keystore" \
    && chmod +x /docker-entrypoint.sh

VOLUME /ThingworxStorage
VOLUME /ThingworxBackupStorage
VOLUME /ThingworxPlatform

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["run"]
