ARG RELEASE_VERSION=Release77
FROM maven:3.6.3-jdk-8 AS builder

RUN mkdir -p /gitroot
WORKDIR /gitroot
LABEL maintainer="solomon.shorser@oicr.on.ca"

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master

# Build the content service
COPY ./content-service-maven-settings.xml /mvn-settings.xml
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_USER ${NEO4J_USER}
ENV NEO4J_PASSWORD ${NEO4J_PASSWORD}
ENV NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASSWORD}"
ENV MVN_CMD "mvn -DskipTests --no-transfer-progress --global-settings /mvn-settings.xml"
RUN cd /gitroot/ && git clone https://github.com/reactome/content-service.git && \
	cd /gitroot/content-service && \
	git checkout $CONTENT_SERVICE_VERSION && \
	cd /gitroot/content-service/src/main/resources && \
# Set logging levels to WARN - otherwise there is a lot of noise on the console.
	echo "log4j.logger.httpclient.wire.header=WARN" >> log4j.properties && echo "log4j.logger.httpclient.wire.content=WARN" >> log4j.properties && echo  "log4j.logger.org.apache.commons.httpclient=WARN" >> log4j.properties && \
	sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml && \
# an empty header/footer is probably OK. The files just need to be present.
	cd /gitroot/content-service/src/main/webapp/WEB-INF/pages/ && touch header.jsp && touch footer.jsp && \
	mkdir /webapps && \
	sed -i -e 's/<neo4j\.password>.*<\/neo4j\.password>/<neo4j\.password>${NEO4J_PASSWORD}<\/neo4j\.password>/g' /mvn-settings.xml && \
	sed -i -e 's/<neo4j\.user>.*<\/neo4j\.user>/<neo4j\.user>${NEO4J_USER}<\/neo4j\.user>/g' /mvn-settings.xml && \
# Build the applications
	cd /gitroot/content-service && ${MVN_CMD} package -P ContentService-Local && \
	cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war && rm -rf ~/.m2

# Get graph database from existing image.
FROM reactome/graphdb:${RELEASE_VERSION} AS graphdb
# Get solr index
FROM reactome/solr:${RELEASE_VERSION} as solr
# Get diagram files.
FROM reactome/diagram-generator:${RELEASE_VERSION} as diagrams
# Get Fireworks files
FROM reactome/fireworks-generator:${RELEASE_VERSION} as fireworks
# Need relational database for SBML export
FROM reactome/reactome-mysql:${RELEASE_VERSION} as relationaldb
# Final re-base will be Tomcat
FROM tomcat:8.5.35-jre8


ENV EXTENSION_SCRIPT=/data/neo4j-init.sh
ENV NEO4J_EDITION=community

RUN useradd neo4j
RUN useradd solr

EXPOSE 8080
# RUN uname -a && exit 2
# Paths for content service
RUN mkdir -p /usr/local/diagram/static && \
	mkdir -p /usr/local/diagram/exporter && \
	mkdir -p /var/www/html/download/current/ehld && \
	mkdir -p /usr/local/interactors/tuple && \
	apt-get update && apt-get install lsb-release -y && \
	apt-get install netcat gosu procps mlocate -y && \
	apt-get autoremove && ln -s  $(which gosu) /bin/su-exec

RUN wget --progress=bar:force https://downloads.mysql.com/archives/get/p/23/file/mysql-server_5.7.33-1ubuntu18.04_amd64.deb-bundle.tar && \
	apt-get update && apt-get install libaio1 libc6 libmecab2 libnuma1 perl -y && \
# MySQL requires newer version of libc6 than what is already in this docker image
	tar -xf mysql-server_5.7.33-1ubuntu18.04_amd64.deb-bundle.tar && ls -lht *.deb && \
	wget --progress=bar:force http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6_2.27-3ubuntu1_amd64.deb && \
	dpkg -i libc6_2.27-3ubuntu1_amd64.deb && \
# OBVIOUSLY don't expose this container to the outside world! Or change the password here and in the application config.
	echo 'mysql-community-server-5.7.33 mysql-community-server/root_password password root' | debconf-set-selections && \
	echo 'mysql-community-server mysql-community-server/root_password password root' | debconf-set-selections  && \
	dpkg -i mysql-common_5.7.33-1ubuntu18.04_amd64.deb && \
	dpkg -i mysql-community-client_5.7.33-1ubuntu18.04_amd64.deb && \
	dpkg -i mysql-client_5.7.33-1ubuntu18.04_amd64.deb && \
	dpkg -i mysql-community-server_5.7.33-1ubuntu18.04_amd64.deb && \
	rm -rf *.deb mysql-server_5.7.33-1ubuntu18.04_amd64.deb-bundle.tar 

# OR maybe just install MySQL from https://dev.mysql.com/get/Downloads/MySQL-5.7/mysql-5.7.34-linux-glibc2.12-i686.tar.gz
# load and set entrypoint
COPY ./wait-for.sh /wait-for.sh
COPY ./entrypoint.sh /content-service-entrypoint.sh
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_USER ${NEO4J_USER}
ENV NEO4J_PASSWORD ${NEO4J_PASSWORD}
ENV NEO4J_AUTH="${NEO4J_USER}/${NEO4J_PASSWORD}"
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/

COPY --from=relationaldb /data/mysql /var/lib/mysql
# COPY --from=relationaldb /usr/bin/mysql* /usr/bin/
# COPY --from=relationaldb /usr/sbin/mysql* /usr/sbin/

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
COPY --from=diagrams /diagrams /usr/local/diagram/static
COPY --from=fireworks /fireworks-json-files /usr/local/tomcat/webapps/download/current/fireworks
# COPY --from=relationaldb /usr/lib/x86_64-linux-gnu/libaio.so.1 /usr/lib/x86_64-linux-gnu/libaio.so.1
# COPY --from=relationaldb /usr/lib/x86_64-linux-gnu/libaio.so.1.0.1 /usr/lib/x86_64-linux-gnu/libaio.so.1.0.1
RUN chmod a+x /content-service-entrypoint.sh
CMD ["/content-service-entrypoint.sh"]

# Run this as: docker run --name reactome-content-service -p 8888:8080 reactome/stand-alone-content-service:R71
# Access in you browser: http://localhost:8888/ContentService - this will let you see the various services.
# To use from the command-line:
# curl -X GET "http://localhost:8888/ContentService/data/complex/R-HSA-5674003/subunits?excludeStructures=false" -H "accept: application/json"
# For exporter endpoints the return PDF files or images, be sure to use "--output FILE" with curl. For example:
# curl --output R-HSA-177929_event.PDF -X GET "http://localhost:8888/ContentService/exporter/document/event/R-HSA-177929.pdf?level%20%5B0%20-%201%5D=1&diagramProfile=Modern&resource=total&analysisProfile=Standard" -H "accept: application/pdf"
