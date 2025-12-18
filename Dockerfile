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
RUN mvn clean package spring-boot:repackage -DskipTests

# Find and prepare the executable JAR/WAR in build stage
# Project creates ROOT.war or ROOT-classes.jar - we need the WAR with dependencies
RUN cd /app/target && \
    echo "=== Listing all files in target ===" && \
    ls -lah && \
    echo "" && \
    echo "=== Looking for executable WAR or JAR ===" && \
    # First, try to find ROOT.war (Spring Boot executable WAR) \
    if [ -f "ROOT.war" ]; then \
        echo "✅ Found ROOT.war" && \
        cp ROOT.war /app/target/app.jar && \
        echo "✅ Copied ROOT.war to app.jar" && \
        exit 0; \
    fi && \
    # Look for JAR with Main-Class \
    EXECUTABLE_JAR="" && \
    for jar in *.jar; do \
        if [ -f "$jar" ] && ! echo "$jar" | grep -qE "(sources|javadoc)"; then \
            if unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -qi "Main-Class"; then \
                MAIN_CLASS=$(unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" | cut -d: -f2 | tr -d '\r\n ') && \
                echo "✅ Found executable JAR: $jar (Main-Class: $MAIN_CLASS)" && \
                EXECUTABLE_JAR="$jar" && \
                break; \
            fi; \
        fi; \
    done && \
    if [ -n "$EXECUTABLE_JAR" ]; then \
        cp "$EXECUTABLE_JAR" /app/target/app.jar && \
        echo "✅ Copied $EXECUTABLE_JAR to app.jar"; \
    else \
        echo "⚠️ No executable WAR/JAR found, using ROOT-classes.jar (will need dependencies)" && \
        if [ -f "ROOT-classes.jar" ]; then \
            cp ROOT-classes.jar /app/target/app.jar && \
            echo "✅ Copied ROOT-classes.jar to app.jar"; \
        else \
            echo "❌ Error: No JAR/WAR found"; \
            ls -la; \
            exit 1; \
        fi; \
    fi

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

