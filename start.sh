#!/bin/sh
set -e

# Set defaults if not provided
PORT=${PORT:-8080}
JAVA_OPTS=${JAVA_OPTS:--Xmx512m -Xms256m}

# HAPI FHIR JPA Server main class
# Try to detect from manifest, or use common Spring Boot main class patterns
MAIN_CLASS=""
if [ -f app.jar ]; then
    # Try to extract Main-Class from manifest
    MAIN_CLASS=$(unzip -p app.jar META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" | cut -d: -f2 | tr -d '\r\n ' || echo "")
fi

# If no Main-Class in manifest, try common HAPI FHIR/Spring Boot main classes
if [ -z "$MAIN_CLASS" ]; then
    # Common Spring Boot main class patterns for HAPI FHIR
    MAIN_CLASS="ca.uhn.fhir.jpa.starter.Application"
fi

# Execute Java with explicit main class or as executable JAR
if [ -n "$MAIN_CLASS" ] && [ "$MAIN_CLASS" != "" ]; then
    echo "Starting with main class: $MAIN_CLASS"
    exec java $JAVA_OPTS -cp app.jar $MAIN_CLASS --server.port=$PORT
else
    echo "Starting as executable JAR"
    exec java $JAVA_OPTS -jar app.jar --server.port=$PORT
fi

