FROM maven:3.5-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=master
RUN mkdir -p /gitroot
RUN mkdir -p /webapps
WORKDIR /gitroot

ENV ANALYSIS_REPORT_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/analysis-report.git \
  && cd /gitroot/analysis-report \
  && git checkout $ANALYSIS_REPORT_VERSION

ENV ANALYSIS_SERVICE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/analysis-service.git \
  && cd /gitroot/analysis-service \
  && git checkout $ANALYSIS_SERVICE_VERSION

COPY ./analysis-service-maven-settings.xml /maven-settings.xml

RUN cd /gitroot/analysis-report \
	&& mvn --global-settings  /maven-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ -DskipTests clean compile package install \
	&& ls ./target/


RUN cd /gitroot/analysis-service \
	&& mvn --global-settings  /maven-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ package -DskipTests -P AnalysisService-Local
RUN ls -lht /gitroot/analysis-service/target && cp /gitroot/analysis-service/target/AnalysisService.war /webapps/ && du -hscx /mvn/alt-m2/ && ls -lht /webapps/

# FROM tomcat:7.0.91-jre8

# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/

RUN ls -lht /usr/local/tomcat/webapps/
