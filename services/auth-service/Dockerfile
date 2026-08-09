# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/auth-service -am -DskipTests package
#   docker build -t bank/auth-service:0.1.0 services/auth-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/auth-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
