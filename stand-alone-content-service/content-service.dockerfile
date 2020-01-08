ARG RELEASE_VERSION=R71a
FROM maven:3.6.3-jdk-8 AS builder
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
ENV MVN_CMD "mvn --no-transfer-progress --global-settings  /mvn-settings.xml"
RUN cd /gitroot/content-service && $MVN_CMD package -P ContentService-Local \
  && cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war

# Get graph database from existing image.
FROM reactome/graphdb:R71a AS graphdb

# Get solr index
FROM reactome/solr:R71a as solr

# Ok, now re-base the image as Tomcat
FROM tomcat:8.5.35-jre8

ENV EXTENSION_SCRIPT=/data/neo4j-init.sh
ENV NEO4J_EDITION=community
ENV NEO4J_AUTH=neo4j/neo4j-password
RUN useradd neo4j
RUN useradd solr

EXPOSE 8080

# Paths for content service
RUN mkdir -p /usr/local/diagram/static && \
	mkdir -p /usr/local/diagram/exporter && \
	mkdir -p /var/www/html/download/current/ehld && \
	mkdir -p /usr/local/interactors/tuple
RUN apt-get update && apt-get install netcat gosu procps -y && apt-get autoremove && ln -s  $(which gosu) /bin/su-exec
# load and set entrypoint
COPY ./wait-for.sh /wait-for.sh
COPY ./entrypoint.sh /content-service-entrypoint.sh

# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
# Copy graph database
COPY --from=graphdb /var/lib/neo4j /var/lib/neo4j
COPY --from=graphdb /var/lib/neo4j/logs /var/lib/neo4j/logs
COPY --from=graphdb /logs /var/lib/neo4j/logs
COPY --from=graphdb /var/lib/neo4j/bin/neo4j-admin /var/lib/neo4j/bin/neo4j-admin
COPY --from=graphdb /data/neo4j-init.sh /data/neo4j-init.sh
COPY --from=graphdb /var/lib/neo4j/conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY --from=graphdb /docker-entrypoint.sh /neo4j-entrypoint.sh
COPY --from=graphdb /data /var/lib/neo4j/data
COPY --from=solr /opt/docker-solr /opt/docker-solr
COPY --from=solr /opt/mysolrhome /opt/mysolrhome
COPY --from=solr /opt/solr /opt/solr
COPY --from=solr /custom-solr-conf /custom-solr-conf
COPY --from=solr /docker-entrypoint-initdb.d /docker-entrypoint-initdb.d
RUN chmod a+x /content-service-entrypoint.sh
CMD ["/content-service-entrypoint.sh"]

# Run this as: docker run --name content-service --rm -v $(pwd)/reactome.graphdb.v66:/neo4j/neo4j-community-3.4.10/data/databases/graph.db -p 8888:8080 reactome_content_service
