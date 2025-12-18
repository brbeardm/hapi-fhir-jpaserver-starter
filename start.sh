#!/bin/sh
set -e

# Set defaults if not provided
PORT=${PORT:-8080}
JAVA_OPTS=${JAVA_OPTS:--Xmx512m -Xms256m}

# Check if app.jar has Main-Class (executable JAR/WAR)
if unzip -p app.jar META-INF/MANIFEST.MF 2>/dev/null | grep -qi "Main-Class"; then
    # Executable JAR/WAR - run directly
    echo "Starting as executable JAR/WAR"
    exec java $JAVA_OPTS -jar app.jar --server.port=$PORT
else
    # No Main-Class - try to run as WAR with embedded Tomcat
    # Spring Boot can run WAR files with embedded Tomcat
    echo "Starting WAR with Spring Boot embedded Tomcat"
    exec java $JAVA_OPTS org.springframework.boot.loader.WarLauncher --server.port=$PORT || \
         java $JAVA_OPTS -cp app.jar:BOOT-INF/classes:BOOT-INF/lib/* ca.uhn.fhir.jpa.starter.Application --server.port=$PORT
fi

