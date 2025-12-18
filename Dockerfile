# HAPI FHIR JPA Server - Dockerfile for Railway
# Based on: https://github.com/hapifhir/hapi-fhir-jpaserver-starter

FROM maven:3.9-eclipse-temurin-17 AS build

# Set working directory
WORKDIR /app

# Clone the HAPI FHIR JPA Server Starter repository
# Note: Railway builds from your GitHub repo, so we use the repo Railway provides
# The application.yaml is already in the repo at src/main/resources/application.yaml
WORKDIR /app

# Copy all files from build context (Railway provides the cloned repo)
COPY . .

# Build the application
RUN mvn clean install -DskipTests

# Find and prepare the executable JAR in build stage
# Spring Boot creates a "fat JAR" with all dependencies - find the one with Main-Class
RUN cd /app/target && \
    echo "=== Listing all JARs ===" && \
    ls -lh *.jar 2>/dev/null || true && \
    echo "" && \
    echo "=== Finding JAR with Main-Class ===" && \
    for jar in *.jar; do \
        if [ -f "$jar" ] && ! echo "$jar" | grep -qE "(sources|javadoc)"; then \
            echo "Checking $jar..." && \
            if unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -qi "Main-Class"; then \
                echo "✅ Found executable JAR: $jar" && \
                MAIN_CLASS=$(unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" | cut -d: -f2 | tr -d '\r\n ') && \
                echo "   Main-Class: $MAIN_CLASS" && \
                cp "$jar" /app/target/app.jar && \
                echo "   Copied to app.jar" && \
                exit 0; \
            fi; \
        fi; \
    done && \
    echo "⚠️ No JAR with Main-Class found, trying largest JAR..." && \
    JARFILE=$(ls -1S *.jar 2>/dev/null | grep -v sources | grep -v javadoc | head -1) && \
    if [ -z "$JARFILE" ]; then \
        echo "❌ Error: No JAR found in target directory"; \
        ls -la /app/target/; \
        exit 1; \
    fi && \
    echo "Using largest JAR: $JARFILE" && \
    cp "$JARFILE" /app/target/app.jar

# Runtime stage
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Copy the built JAR from build stage
COPY --from=build /app/target/app.jar app.jar

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose port (Railway will set PORT env var, but HAPI defaults to 8080)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/fhir/metadata || exit 1

# Run the application
# HAPI FHIR reads PORT from environment or defaults to 8080
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENTRYPOINT ["/start.sh"]

