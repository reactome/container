FROM maven:3.6.3-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/ && mkdir /webapps && mkdir /gitroot
ENV MVN_CMD "mvn --no-transfer-progress --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ -DskipTests"

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master
# Get source code
RUN cd /gitroot/ \
  && git clone https://github.com/reactome/content-service.git \
  && cd /gitroot/content-service \
  && git checkout $CONTENT_SERVICE_VERSION
# Build the content service
RUN cd /gitroot/content-service/src/main/resources \
  && echo "log4j.logger.httpclient.wire.header=WARN" >> log4j.properties && echo "log4j.logger.httpclient.wire.content=WARN" >> log4j.properties && echo  "log4j.logger.org.apache.commons.httpclient=WARN" >> log4j.properties \
  && sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml \
  && cd /gitroot/content-service \
  && sed -i -e 's/<url>http/<url>https/g' pom.xml \
  && sed -i -e 's/http:\/\/repo/https:\/\/repo/g' pom.xml \
  && ${MVN_CMD} package -P ContentService-Local \
  && cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war && du -hscx /mvn/alt-m2/

FROM alpine:3.8
COPY --from=builder /webapps/ContentService.war /webapps/ContentService.war
