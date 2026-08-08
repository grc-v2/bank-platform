# Build context là thư mục service này. Jar phải được build TRƯỚC:
#   mvn -pl services/product-service -am -DskipTests package
#   docker build -t bank/product-service:0.1.0 services/product-service
FROM eclipse-temurin:21-jre
WORKDIR /app
ARG JAR_FILE=target/product-service-0.1.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
