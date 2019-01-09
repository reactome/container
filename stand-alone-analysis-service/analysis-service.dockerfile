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

# Empty header/footer should be OK since this is a stand-alone version of AnalysisService.
# Later, we can get a proper Reactome header/footer, if we want the AnalysisService UI to look nicer.
RUN echo "" > /gitroot/analysis-service/src/main/webapp/WEB-INF/pages/header.jsp
RUN echo "" > /gitroot/analysis-service/src/main/webapp/WEB-INF/pages/footer.jsp

RUN cd /gitroot/analysis-service \
	&& mvn --global-settings  /maven-settings.xml -Dmaven.repo.local=/mvn/alt-m2/ package -DskipTests -P AnalysisService-Local
RUN ls -lht /gitroot/analysis-service/target && cp /gitroot/analysis-service/target/AnalysisService.war /webapps/ && du -hscx /mvn/alt-m2/ && ls -lht /webapps/

# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
RUN mkdir -p /usr/local/AnalysisService/analysis-results
RUN ls -lht /usr/local/tomcat/webapps/

RUN rm -rf /mvn/alt-m2/

COPY ./analysis.bin /analysis.bin

# It looks like Neo4j is necessary for parts of the AnalysisService
RUN mkdir /neo4j
WORKDIR /neo4j
RUN wget -nv https://neo4j.com/artifact.php?name=neo4j-community-3.4.10-unix.tar.gz -O neo4j-community-3.4.10-unix.tar.gz
RUN ls -lht
RUN gunzip neo4j-community-3.4.10-unix.tar.gz \
	&& tar -xf neo4j-community-3.4.10-unix.tar \
	&& ls -lht \
	&& rm neo4j-community-3.4.10-unix.tar

EXPOSE 8080
# load and set entrypoint
COPY ./entrypoint.sh /analysis-service-entrypoint.sh
RUN chmod a+x /analysis-service-entrypoint.sh
CMD ["/analysis-service-entrypoint.sh"]

# Run this as: docker run --name analysis-service --rm -v $(pwd)/reactome.graphdb.v66:/neo4j/neo4j-community-3.4.10/data/databases/graph.db -p 8888:8080 reactome_analysis_service
