#!/bin/bash

HOST="0.0.0.0"

# As of Tomcat 9.0.29 the CATALINA_OPTS are surrounded by quotes in catalina.sh
CATALINA_OPTS="-Dserver -Dd64\
 -Xms${INITIAL_HEAP}g\
 -Xmx${MAX_HEAP}g\
 -XX:+UseNUMA\
 -XX:+UseG1GC\
 -Djsse.enableSNIExtension=${ENABLE_SNI}\
 -Djava.net.preferIPv4Stack=true\
 -Dcom.sun.management.jmxremote\
 -Dcom.sun.management.jmxremote.port=${JMX_ADDRESS}\
 -Dcom.sun.management.jmxremote.rmi.port=${JMX_ADDRESS}\
 -Dcom.sun.management.jmxremote.ssl=false\
 -Dcom.sun.management.jmxremote.authenticate=false\
 -Dcom.sun.management.jmxremote.host=$HOST\
 -Djava.rmi.server.hostname=$HOST\
 -DTHINGWORX_STORAGE=${THINGWORX_STORAGE}\
 -XX:HeapDumpPath=${THINGWORX_STORAGE}/logs\
 -XX:+PrintGCTimeStamps\
 -XX:+PrintGCDetails\
 -Xloggc:${THINGWORX_STORAGE}/logs/tomcat-twx-gc.log\
 -Dfile.encoding=UTF-8\
 -Djava.library.path=${CATALINA_HOME}/webapps/Thingworx/WEB-INF/extensions"