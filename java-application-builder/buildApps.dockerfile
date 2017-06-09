FROM maven:3.5-jdk-8
#RUN apt-get update
#RUN apt-get install -y git
ENV PATHWAY_BROWSER_VERSION=v3.2.0
RUN mkdir -p /gitroot
WORKDIR /gitroot

VOLUME /root/.m2

RUN git clone https://github.com/reactome-pwp/browser.git
WORKDIR /gitroot/browser
RUN git checkout $PATHWAY_BROWSER_VERSION
RUN mvn  package

WORKDIR /gitroot

# Need diagram-reader for diagram-exporter and it's not in a repo AND I can't find the source code for it.
COPY ./diagram-reader-1.0-SNAPSHOT.jar /root/.m2/repository/org/reactome/server/tools/diagram-reader/1.0-SNAPSHOT/diagram-reader-1.0-SNAPSHOT.jar

# Need Quadtree.
ENV QUADTREE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/quadtree.git
WORKDIR /gitroot/quadtree
RUN git checkout $QUADTREE_VERSION

# Need diagram-exporter for content-service and it's not in a repo so we will build it locally.
ENV DIAGRAM_EXPORTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/diagram-exporter.git
WORKDIR /gitroot/diagram-exporter
RUN git checkout $DIAGRAM_EXPORTER_VERSION
COPY ./diagram-exporter-pom.xml /gitroot/diagram-exporter/pom.xml

ENV CONTENT_SERVICE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/content-service.git
WORKDIR /gitroot/content-service
RUN git checkout $CONTENT_SERVICE_VERSION

RUN cd /gitroot/browser && mvn package && \
	cd /gitroot/quadtree && mvn install && \
	cd /gitroot/diagram-exporter && mvn install && \
	cd /gitroot/content-service && mvn package
# 
# RUN mkdir /webapps && cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war && \
# 	cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war
