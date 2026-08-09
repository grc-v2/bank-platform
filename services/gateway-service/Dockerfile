# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/gateway-service -am -DskipTests package
#   docker build -t bank/gateway-service:0.1.0 services/gateway-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/gateway-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
