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
# Use package and spring-boot:repackage to ensure executable JAR is created
RUN mvn clean package spring-boot:repackage -DskipTests

# Find and prepare the executable JAR in build stage
# After spring-boot:repackage, the executable JAR should be created
RUN cd /app/target && \
    echo "=== Listing all JARs ===" && \
    ls -lh *.jar 2>/dev/null || true && \
    echo "" && \
    echo "=== Finding Spring Boot executable JAR ===" && \
    EXECUTABLE_JAR="" && \
    # First, try to find JAR with Main-Class (the executable one) \
    for jar in *.jar; do \
        if [ -f "$jar" ]; then \
            echo "Checking $jar..." && \
            if unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -qi "Main-Class"; then \
                MAIN_CLASS=$(unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" | cut -d: -f2 | tr -d '\r\n ') && \
                echo "✅ Found executable JAR: $jar (Main-Class: $MAIN_CLASS)" && \
                EXECUTABLE_JAR="$jar" && \
                break; \
            fi; \
        fi; \
    done && \
    # If no JAR with Main-Class, try largest JAR (excluding sources/javadoc) \
    if [ -z "$EXECUTABLE_JAR" ]; then \
        echo "⚠️ No JAR with Main-Class found, trying largest JAR..." && \
        EXECUTABLE_JAR=$(ls -1S *.jar 2>/dev/null | grep -v sources | grep -v javadoc | head -1); \
        if [ -n "$EXECUTABLE_JAR" ]; then \
            echo "Using largest JAR: $EXECUTABLE_JAR" && \
            echo "⚠️ WARNING: This JAR may not have Main-Class - checking..." && \
            if ! unzip -p "$EXECUTABLE_JAR" META-INF/MANIFEST.MF 2>/dev/null | grep -qi "Main-Class"; then \
                echo "❌ ERROR: $EXECUTABLE_JAR does not have Main-Class!" && \
                echo "This JAR cannot be executed. Available JARs:" && \
                ls -la *.jar 2>/dev/null || true && \
                exit 1; \
            fi; \
        fi; \
    fi && \
    if [ -z "$EXECUTABLE_JAR" ] || [ ! -f "$EXECUTABLE_JAR" ]; then \
        echo "❌ Error: No executable JAR found"; \
        echo "Available JARs:"; \
        ls -la *.jar 2>/dev/null || true; \
        exit 1; \
    fi && \
    echo "Using JAR: $EXECUTABLE_JAR" && \
    cp "$EXECUTABLE_JAR" /app/target/app.jar && \
    echo "✅ Copied $EXECUTABLE_JAR to app.jar" && \
    echo "Verifying app.jar has Main-Class:" && \
    unzip -p /app/target/app.jar META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" && \
    echo "✅ Verified: app.jar has Main-Class"

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

