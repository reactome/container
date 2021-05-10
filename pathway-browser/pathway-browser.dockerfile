ARG RELEASE_VERSION=Release75
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

# Build PathwayBrowser. Use sed to get rid of the "Downloads" tab.
RUN git clone https://github.com/reactome-pwp/browser.git \
  && cd /gitroot/browser \
  && git checkout $PATHWAY_BROWSER_VERSION \
  && cd /gitroot/browser \
  && sed -i 's/\(DownloadsTab\.Display downloads = new\)/\/\/ \1/g' ./src/main/java/org/reactome/web/pwp/client/AppController.java \
  && sed -i 's/\(new DownloadsTabPresenter(this\.eventBus, downloads);\)/\/\/ \1/g' ./src/main/java/org/reactome/web/pwp/client/AppController.java \
  && sed -i 's/\(DETAILS_TABS\.add(downloads);\)/\/\/ \1/g' ./src/main/java/org/reactome/web/pwp/client/AppController.java \
	&& sed -i 's/https:\/\/127.0.0.1/http:\/\/localhost:8080/g' ./src/main/java/org/reactome/web/pwp/client/tools/analysis/tissues/TissueDistribution.java \
	&& sed -i 's/<neo4j\.password>.*<\/neo4j\.password>/<neo4j.password>'${NEO4J_PASSWORD}'<\/neo4j.password>/g'  /maven-settings.xml \
  && $MVN_CMD gwt:import-sources compile package \
  && mv /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war
# COPY github.token /tmp/github.token
ARG GITHUB_TOKEN
RUN cd /webapps && git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/reactome-pwp/reacfoam.git && cd reacfoam && git checkout demo-version && rm -rf .git
# && rm /tmp/github.token
RUN git clone https://github.com/reactome/experiment-digester.git

RUN cd /gitroot/experiment-digester \
  && $MVN_CMD -P Experiment-Digester-Local package -DskipTests \
  && ls -lht /gitroot/experiment-digester/target

# Generate the experiments.bin file
RUN cd /gitroot/experiment-digester && \
  java -jar target/digester-importer-jar-with-dependencies.jar \
    -o /experiments.bin \
    -e https://www.ebi.ac.uk/gxa/experiments-content/E-PROT-3/resources/ExperimentDownloadSupplier.Proteomics/tsv && \
  ls -lht /experiments.bin

RUN cp /gitroot/experiment-digester/target/ExperimentDigester.war /webapps/
RUN cp /experiments.bin /webapps/experiments.bin

FROM reactome/analysis-core:${RELEASE_VERSION} AS analysiscorebuilder
FROM reactome/stand-alone-analysis-service:${RELEASE_VERSION} AS analysisservice
FROM reactome/stand-alone-content-service:${RELEASE_VERSION} AS contentservice
FROM reactome/graphdb:${RELEASE_VERSION} AS graphdb
FROM reactome/fireworks-generator:${RELEASE_VERSION} as fireworks
FROM reactome/diagram-generator:${RELEASE_VERSION} as diagrams
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

# Paths for content service
RUN mkdir -p /usr/local/diagram/static && \
  mkdir -p /usr/local/diagram/exporter && \
  mkdir -p /var/www/html/download/current/ehld && \
  mkdir -p /usr/local/interactors/tuple

COPY ./entrypoint.sh /entrypoint.sh
RUN mkdir -p /usr/local/AnalysisService/analysis-results \
  && useradd neo4j \
  && chmod a+x /entrypoint.sh
# Copy the analysis file
COPY --from=fireworks /fireworks-json-files /tmp/fireworks
# ContentService expects fireworks to be in a different location...
# And since we're relying on a pre-built image for ContentService AND AnalysisService,
# It's easier to just put Fireworks in both places. Future TODO: make all images use the same location, for consistency.
RUN mkdir -p /usr/local/tomcat/webapps/download/current/ \
	&& cp -r /tmp/fireworks /usr/local/tomcat/webapps/download/current/fireworks \
	&& rm -rf /tmp/fireworks

COPY --from=analysiscorebuilder /output/analysis.bin /analysis.bin
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
COPY --from=builder /webapps/experiments.bin /experiments.bin
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

# Set up links to fireworks files for reacfoam
RUN cd /usr/local/tomcat/webapps/reacfoam/resources/dataset/fireworks \
	&& rm -rf * \
	&& for f in $(ls /usr/local/tomcat/webapps/download/current/fireworks) ; do ln /usr/local/tomcat/webapps/download/current/fireworks/$f  ./$f ; done

# Files needed for the PathwayBrowser
ADD https://reactome.org/download/current/ehlds.tgz /usr/local/tomcat/webapps/download/current/ehld.tgz
RUN cd /usr/local/tomcat/webapps/download/current && tar -zxf ehld.tgz && rm ehld.tgz
ADD https://reactome.org/download/current/ehld/svgsummary.txt /usr/local/tomcat/webapps/download/current/ehld/svgsummary.txt
RUN chmod a+r /usr/local/tomcat/webapps/download/current/ehld/svgsummary.txt


# load and set entrypoint
CMD ["/entrypoint.sh"]
RUN apt-get update && apt-get install netcat gosu procps -y && apt-get autoremove && ln -s  $(which gosu) /bin/su-exec
# Run this as: docker run --name reactome-analysis-service -p 8080:8080 reactome/stand-alone-analysis-service:Release71
