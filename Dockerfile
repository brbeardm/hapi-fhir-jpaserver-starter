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
# Spring Boot creates a "fat JAR" with all dependencies - it's usually the largest one
# Or we can check for Main-Class in the manifest
RUN cd /app/target && \
    echo "Listing all JARs:" && \
    ls -lh *.jar 2>/dev/null || true && \
    echo "" && \
    echo "Finding executable JAR (largest non-sources/javadoc JAR):" && \
    JARFILE=$(ls -1S *.jar 2>/dev/null | grep -v sources | grep -v javadoc | head -1) && \
    if [ -z "$JARFILE" ]; then \
        echo "Error: No executable JAR found in target directory"; \
        ls -la /app/target/; \
        exit 1; \
    fi && \
    echo "Selected JAR: $JARFILE" && \
    echo "Checking for Main-Class in manifest:" && \
    unzip -p "$JARFILE" META-INF/MANIFEST.MF 2>/dev/null | grep -i "Main-Class" || echo "WARNING: No Main-Class found in manifest" && \
    cp "$JARFILE" /app/target/app.jar && \
    echo "Copied $JARFILE to app.jar"

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

