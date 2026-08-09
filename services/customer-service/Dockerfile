# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/customer-service -am -DskipTests package
#   docker build -t bank/customer-service:0.1.0 services/customer-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/customer-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
