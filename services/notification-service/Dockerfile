# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/notification-service -am -DskipTests package
#   docker build -t bank/notification-service:0.1.0 services/notification-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/notification-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8085
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
