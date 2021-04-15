ARG RELEASE_VERSION=Release75
FROM maven:3.6.3-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=master
RUN mkdir -p /gitroot && mkdir -p /webapps
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
RUN sed -i -e 's/<neo4j\.password>.*<\/neo4j\.password>/<neo4j\.password>${NEO4J_PASSWORD}<\/neo4j\.password>/g' /maven-settings.xml && \
		sed -i -e 's/<neo4j\.user>.*<\/neo4j\.user>/<neo4j\.user>${NEO4J_USER}<\/neo4j\.user>/g' /maven-settings.xml

# Build the applications
RUN cd /gitroot/ && git clone https://github.com/reactome/analysis-report.git \
	&& cd /gitroot/analysis-report \
	&& git checkout $ANALYSIS_REPORT_VERSION \
	&& cd /gitroot/ && git clone https://github.com/reactome/analysis-service.git \
	&& cd /gitroot/analysis-service \
	&& git checkout $ANALYSIS_SERVICE_VERSION \
# Empty header/footer should be OK since this is a stand-alone version of AnalysisService.
# Later, we can get a proper Reactome header/footer, if we want the AnalysisService UI to look nicer.
	&& echo "" > /gitroot/analysis-service/src/main/webapp/WEB-INF/pages/header.jsp \
	&& echo "" > /gitroot/analysis-service/src/main/webapp/WEB-INF/pages/footer.jsp \
	&& cd /gitroot/analysis-report \
	&& ${MVN_CMD} clean compile package install \
	&& ls ./target/ \
	&& cd /gitroot/analysis-service \
	&& sed -i -e 's/http:\/\/repo\.maven/https:\/\/repo\.maven/g' pom.xml \
	&& ${MVN_CMD} clean compile package -P AnalysisService-Local \
	&& ls -lht target && mv target/*.war /webapps/ \
	&& rm -rf /mvn/alt-m2/

FROM reactome/analysis-core:${RELEASE_VERSION} AS analysiscorebuilder
FROM reactome/graphdb:${RELEASE_VERSION} AS graphdb
FROM reactome/fireworks-generator:${RELEASE_VERSION} as fireworks
# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8
ENV EXTENSION_SCRIPT=/data/neo4j-init.sh
ENV NEO4J_EDITION=community
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_USER ${NEO4J_USER}
ENV NEO4J_PASSWORD ${NEO4J_PASSWORD}
ENV NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASSWORD}"
EXPOSE 8080
COPY ./entrypoint.sh /analysis-service-entrypoint.sh
RUN mkdir -p /usr/local/AnalysisService/analysis-results \
	&& useradd neo4j \
	&& chmod a+x /analysis-service-entrypoint.sh
# Copy the analysis file
COPY --from=fireworks /fireworks-json-files /tmp/fireworks
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
COPY ./wait-for.sh /wait-for.sh
# load and set entrypoint

CMD ["/analysis-service-entrypoint.sh"]
RUN apt-get update && apt-get install netcat gosu procps -y && apt-get autoremove && ln -s  $(which gosu) /bin/su-exec
# Run this as: docker run --name reactome-analysis-service -p 8080:8080 reactome/stand-alone-analysis-service:Release71
