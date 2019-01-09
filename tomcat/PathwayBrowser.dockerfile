FROM maven:3.6.0-jdk-8 AS builder

RUN mkdir -p /gitroot
WORKDIR /gitroot
LABEL maintainer="solomon.shorser@oicr.on.ca"
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
RUN mkdir /webapps
ENV MVN_CMD "mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

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
