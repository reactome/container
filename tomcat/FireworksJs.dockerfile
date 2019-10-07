FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV FIREWORKS_VERSION=6cc85f3715116536fcda83e989fb0f27465dfd9c
RUN cd /gitroot && git clone https://github.com/reactome-pwp/fireworks.git \
  && cd /gitroot/fireworks \
  && git checkout $FIREWORKS_VERSION

RUN cd /gitroot/fireworks \
  && $MVN_CMD package install -DskipTests

ENV FIREWORKSJS_VERSION=f8142f77c242b40ffc4df635070fa9f5dddeba26
RUN cd /gitroot/ && git clone https://github.com/reactome-pwp/fireworks-js.git \
  && cd /gitroot/fireworks-js \
  && git checkout $FIREWORKSJS_VERSION

RUN cd /gitroot/fireworks-js \
  && $MVN_CMD package -DskipTests \
  && ls -lht /gitroot/fireworks-js/target
RUN cp /gitroot/fireworks-js/target/fireworks*war /webapps/

FROM alpine:3.8
COPY --from=builder /webapps /webapps
