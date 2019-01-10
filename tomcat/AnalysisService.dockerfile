FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot

COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV ANALYSIS_REPORT_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/analysis-report.git \
  && cd /gitroot/analysis-report \
  && git checkout $ANALYSIS_REPORT_VERSION

ENV ANALYSIS_SERVICE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/analysis-service.git \
  && cd /gitroot/analysis-service \
  && git checkout $ANALYSIS_SERVICE_VERSION

# COPY ./java-build-mounts/AnalysisService_mvc-dispatcher-servlet.xml /gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/mvc-dispatcher-servlet.xm
# COPY ./java-build-mounts/AnalysisTools-Service-web.xml /gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/web.xml

RUN cd /gitroot/analysis-report \
  && mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ -DskipTests clean compile package install \
  && ls ./target/

RUN cd /gitroot/analysis-service \
  && mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ package -DskipTests -P AnalysisService-Local

RUN ls -lht /gitroot/analysis-service/target && cp /gitroot/analysis-service/target/AnalysisService.war /webapps/ && du -hscx /mvn/alt-m2/ && ls -lht /webapps/
