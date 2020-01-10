FROM maven:3.6.3-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --no-transfer-progress --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

WORKDIR /gitroot
ENV PATHWAY_BROWSER_VERSION=master
RUN git clone https://github.com/reactome-pwp/browser.git \
  && cd /gitroot/browser \
  && git checkout $PATHWAY_BROWSER_VERSION

RUN git clone https://github.com/reactome-pwp/analysis-client.git \
  && cd /gitroot/analysis-client \
  && git checkout dev \
  && $MVN_CMD clean compile package install

# Build PathwayBrowser
WORKDIR /gitroot/browser
RUN $MVN_CMD clean compile package
RUN cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war && du -hscx /mvn/alt-m2/

FROM alpine:3.8
COPY --from=builder /webapps/PathwayBrowser.war /webapps/PathwayBrowser.war
