###############################################################################
# ---------- Stage 1: build the application ----------------------------------
###############################################################################
FROM maven:3.9.5-eclipse-temurin-17-alpine AS build          # ⬅️ full JDK + Maven
WORKDIR /workspace

# Copy Maven wrapper & project files first to leverage Docker layer cache
COPY mvnw .
COPY .mvn  .mvn
COPY pom.xml .

# Download dependencies only (helps cache layers)
RUN ./mvnw --batch-mode --no-transfer-progress dependency:resolve-plugins dependency:go-offline

# Copy source last – changes here invalidate only the layers that follow
COPY src  src

# Build the fat jar; skip tests for CI speed
ARG MAVEN_FLAGS="-DskipTests"
RUN ./mvnw --batch-mode --no-transfer-progress ${MAVEN_FLAGS} package

###############################################################################
# ---------- Stage 2: create the runtime image --------------------------------
###############################################################################
FROM eclipse-temurin:17-jre-alpine                               # ⬅️ tiny JRE only
WORKDIR /app

# Let TeamCity override the jar name if it differs (e.g., myapp-1.2.3.jar)
ARG JAR_FILE=target/*-SNAPSHOT.jar
COPY --from=build /workspace/${JAR_FILE} app.jar

# Use a non-root user for security
RUN addgroup -S javauser && adduser -S -G javauser -s /sbin/nologin javauser \
 && chown -R javauser:javauser /app
USER javauser

# Optional: JVM flags tuned for small containers
ENV JAVA_TOOL_OPTIONS="-XX:+UnlockExperimentalVMOptions -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 8080
ENTRYPOINT ["java","-jar","app.jar"]
