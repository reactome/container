FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/content-service.git \
  && cd /gitroot/content-service \
  && git checkout $CONTENT_SERVICE_VERSION

# Build the content service
WORKDIR /gitroot/content-service/src/main/resources
RUN echo "log4j.logger.httpclient.wire.header=WARN" >> log4j.properties && echo "log4j.logger.httpclient.wire.content=WARN" >> log4j.properties && echo  "log4j.logger.org.apache.commons.httpclient=WARN" >> log4j.properties
RUN sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml
RUN cd /gitroot/content-service && $MVN_CMD package -P ContentService-Local
RUN cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war && du -hscx /mvn/alt-m2/

FROM alpine:3.8
COPY --from=builder /webapps/ContentService.war /webapps/ContentService.war
