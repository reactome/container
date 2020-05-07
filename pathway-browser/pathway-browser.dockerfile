ARG RELEASE_VERSION=Release72
FROM maven:3.6.3-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=master
RUN mkdir -p /gitroot && \
	mkdir -p /webapps
WORKDIR /gitroot
ENV ANALYSIS_SERVICE_VERSION=master
ENV ANALYSIS_REPORT_VERSION=master
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_USER ${NEO4J_USER}
ENV NEO4J_PASSWORD ${NEO4J_PASSWORD}
ENV NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASSWORD}"
ENV MVN_CMD="mvn --no-transfer-progress --global-settings /maven-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ -DskipTests"
COPY ./analysis-service-maven-settings.xml /maven-settings.xml
# Now build the PathwayBrowser
WORKDIR /gitroot
ENV PATHWAY_BROWSER_VERSION=master
RUN git clone https://github.com/reactome-pwp/browser.git \
  && cd /gitroot/browser \
  && git checkout $PATHWAY_BROWSER_VERSION \
  && cd /gitroot/browser \
	# && mv /tmp/PwB-web.xml ./src/main/webapp/WEB-INF/web.xml \
  && $MVN_CMD gwt:import-sources compile package \
  && mv /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war

# TODO: Search in PathwayBrowser's AppController.java class and remove these lines:
# DownloadsTab.Display downloads = new DownloadsTabDisplay();
# new DownloadsTabPresenter(this.eventBus, downloads);
# DETAILS_TABS.add(downloads);

FROM reactome/analysis-core AS analysiscorebuilder
FROM reactome/stand-alone-analysis-service:${RELEASE_VERSION} AS analysisservice
FROM reactome/stand-alone-content-service:${RELEASE_VERSION} AS contentservice
FROM reactome/graphdb:${RELEASE_VERSION} AS graphdb
FROM reactome/fireworks-generator as fireworks
FROM reactome/diagram-generator as diagrams
# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8
ENV EXTENSION_SCRIPT=/data/neo4j-init.sh
ENV NEO4J_EDITION=community
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=n304j
ENV NEO4J_USER ${NEO4J_USER}
ENV NEO4J_PASSWORD ${NEO4J_PASSWORD}
ENV NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASSWORD}"
EXPOSE 8080

# Paths for content service
RUN mkdir -p /usr/local/diagram/static && \
	mkdir -p /usr/local/diagram/exporter && \
	mkdir -p /var/www/html/download/current/ehld && \
	mkdir -p /usr/local/interactors/tuple

COPY ./entrypoint.sh /analysis-service-entrypoint.sh
RUN mkdir -p /usr/local/AnalysisService/analysis-results \
	&& useradd neo4j \
	&& chmod a+x /analysis-service-entrypoint.sh
# Copy the analysis file
COPY --from=fireworks /fireworks-json-files /tmp/fireworks
# ContentService expects fireworks to be in a different location...
RUN mkdir -p /usr/local/tomcat/webapps/download/current/ && cp -r /tmp/fireworks /usr/local/tomcat/webapps/download/current/fireworks

COPY --from=analysiscorebuilder /output/analysis.bin /analysis.bin
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
# Copy graph database
COPY --from=graphdb /data/neo4j-init.sh /data/neo4j-init.sh
COPY --from=graphdb /docker-entrypoint.sh /neo4j-entrypoint.sh
COPY --from=graphdb /var/lib/neo4j /var/lib/neo4j
COPY --from=graphdb /logs /var/lib/neo4j/logs
COPY --from=graphdb /var/lib/neo4j/conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY --from=graphdb /data /var/lib/neo4j/data
COPY --from=analysisservice /usr/local/tomcat/webapps/AnalysisService.war /usr/local/tomcat/webapps/AnalysisService.war
COPY --from=contentservice /usr/local/tomcat/webapps/ContentService.war /usr/local/tomcat/webapps/ContentService.war
COPY --from=diagrams /diagrams /usr/local/tomcat/webapps/download/current/diagram
COPY ./wait-for.sh /wait-for.sh
# load and set entrypoint

# Files needed for the PathwayBrowser
ADD https://reactome.org/download/current/ehlds.tgz /usr/local/tomcat/webapps/download/current/ehld.tgz
RUN cd /usr/local/tomcat/webapps/download/current && tar -zxf ehld.tgz && rm ehld.tgz
ADD https://reactome.org/download/current/ehld/svgsummary.txt /usr/local/tomcat/webapps/download/current/ehld/svgsummary.txt
RUN chmod a+r /usr/local/tomcat/webapps/download/current/ehld/svgsummary.txt


CMD ["/analysis-service-entrypoint.sh"]
RUN apt-get update && apt-get install netcat gosu procps -y && apt-get autoremove && ln -s  $(which gosu) /bin/su-exec
# Run this as: docker run --name reactome-analysis-service -p 8080:8080 reactome/stand-alone-analysis-service:Release71
