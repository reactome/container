FROM maven:3.6.3-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --no-transfer-progress --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV DIAGRAMJS_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/diagram-js.git \
  && cd /gitroot/diagram-js \
  && git checkout $DIAGRAMJS_VERSION \
  && cd /gitroot/diagram-js \
  && sed -i -e 's/http\:\/\/repo/https\:\/\/repo/g' pom.xml \
  && sed -i -e 's/<url>http/<url>https/g' pom.xml \
  && $MVN_CMD package -DskipTests \
  && ls -lht /gitroot/diagram-js/target

RUN cp /gitroot/diagram-js/target/diagram*war /webapps/

FROM alpine:3.8
COPY --from=builder /webapps /webapps
