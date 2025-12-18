#!/bin/sh
set -e

# Set defaults if not provided
PORT=${PORT:-8080}
JAVA_OPTS=${JAVA_OPTS:--Xmx512m -Xms256m}

# Execute Java with options
exec java $JAVA_OPTS -jar app.jar --server.port=$PORT

