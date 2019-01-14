FROM maven:3.6.0-jdk-8 AS builder

RUN mkdir -p /gitroot
WORKDIR /gitroot
LABEL maintainer="solomon.shorser@oicr.on.ca"

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/content-service.git \
  && cd /gitroot/content-service \
  && git checkout $CONTENT_SERVICE_VERSION

# Build the content service
WORKDIR /gitroot/content-service/src/main/resources
# Set logging levels to WARN - otherwise there is a lot of noise on the console.
RUN echo "log4j.logger.httpclient.wire.header=WARN" >> log4j.properties && echo "log4j.logger.httpclient.wire.content=WARN" >> log4j.properties && echo  "log4j.logger.org.apache.commons.httpclient=WARN" >> log4j.properties
RUN sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml
# an empty header/footer is probably OK. The files just need to be present.
RUN cd /gitroot/content-service/src/main/webapp/WEB-INF/pages/ && touch header.jsp && touch footer.jsp
RUN mkdir /webapps
COPY ./content-service-maven-settings.xml /mvn-settings.xml
ENV MVN_CMD "mvn --global-settings  /mvn-settings.xml"
RUN cd /gitroot/content-service && $MVN_CMD package -P ContentService-Local
RUN cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war

# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
RUN ls -lht /usr/local/tomcat/webapps/

# Neo4j is necessary for Content Service
RUN mkdir /neo4j
WORKDIR /neo4j
ENV NEO4J_VERSION="community-3.4.10-unix"
LABEL Neo4jVersion=$NEO4J_VERSION
RUN wget -nv https://neo4j.com/artifact.php?name=neo4j-$NEO4J_VERSION.tar.gz -O neo4j-$NEO4J_VERSION.tar.gz
RUN ls -lht
RUN gunzip neo4j-community-3.4.10-unix.tar.gz \
	&& tar -xf neo4j-community-3.4.10-unix.tar \
	&& ls -lht \
	&& rm neo4j-community-3.4.10-unix.tar
EXPOSE 8080

# Paths for content service
RUN mkdir -p /usr/local/diagram/static && \
	mkdir -p /usr/local/diagram/exporter && \
	mkdir -p /var/www/html/download/current/ehld && \
	mkdir -p /usr/local/interactors/tuple

# load and set entrypoint
COPY ./entrypoint.sh /content-service-entrypoint.sh
RUN chmod a+x /content-service-entrypoint.sh
CMD ["/content-service-entrypoint.sh"]

# Run this as: docker run --name content-service --rm -v $(pwd)/reactome.graphdb.v66:/neo4j/neo4j-community-3.4.10/data/databases/graph.db -p 8888:8080 reactome_content_service
