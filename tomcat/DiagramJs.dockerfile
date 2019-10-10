FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV DIAGRAMJS_VERSION=efabe4d78a654c0c50671f0661258d33d072644e
RUN cd /gitroot/ && git clone https://github.com/reactome-pwp/diagram-js.git \
  && cd /gitroot/diagram-js \
  && git checkout $DIAGRAMJS_VERSION

RUN cd /gitroot/diagram-js \
  && $MVN_CMD package -DskipTests \
  && ls -lht /gitroot/diagram-js/target
RUN cp /gitroot/diagram-js/target/diagram*war /webapps/

FROM alpine:3.8
COPY --from=builder /webapps /webapps
