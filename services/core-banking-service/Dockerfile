# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/core-banking-service -am -DskipTests package
#   docker build -t bank/core-banking-service:0.1.0 services/core-banking-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/core-banking-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8084
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
