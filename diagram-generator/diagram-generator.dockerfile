ARG RELEASE_VERSION=Release75
FROM maven:3.6.3-jdk-8 AS builder

RUN mkdir /gitroot
ENV DIAGRAM_CONVERTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/diagram-converter.git && \
	cd /gitroot/diagram-converter && git checkout $DIAGRAM_CONVERTER_VERSION && \
	cd src/main/resources && \
	echo "log4j.logger.httpclient.wire.header=WARN" >> log4j.properties && \
	echo "log4j.logger.httpclient.wire.content=WARN" >> log4j.properties && \
	echo "log4j.logger.org.apache.commons.httpclient=WARN" >> log4j.properties && \
	echo "log4j.logger.org.apache=WARN" >> log4j.properties && \
	echo "org.neo4j=WARN" >> log4j.properties && \
	echo "logging.level.org.neo4j.ogm.drivers.bolt.request.BoltRequest=WARN" >> log4j.properties && \
	echo "logging.level.org.neo4j.ogm.drivers.embedded.request.EmbeddedRequest=WARN" >> log4j.properties && \
	echo "org.springframework=WARN" >> log4j.properties && \
	sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="org.springframework" level="WARN"\/><logger name="org.neo4j" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml && \
	cd /gitroot/diagram-converter && \
	sed -i -e 's/<exclude>\*\*\/logback\.xml<\/exclude>/ /g' pom.xml && \
	mvn --no-transfer-progress clean compile package -DskipTests && ls -lht ./target && \
	mkdir /diagram-converter && \
	cp /gitroot/diagram-converter/target/diagram-converter-jar-with-dependencies.jar /diagram-converter/diagram-converter-jar-with-dependencies.jar

# Now, rebase on the Reactome Neo4j image
FROM reactome/graphdb:$RELEASE_VERSION as graphdb

# Add MySQL layer, but name it "diagrambuilder" since this is where we will actually create the diagrams.
FROM reactome/reactome-mysql:$RELEASE_VERSION as diagrambuilder
COPY --from=builder /diagram-converter/diagram-converter-jar-with-dependencies.jar /diagram-converter/diagram-converter-jar-with-dependencies.jar
COPY --from=graphdb /var/lib/neo4j /var/lib/neo4j
COPY --from=graphdb /var/lib/neo4j/logs /var/lib/neo4j/logs
COPY --from=graphdb /var/lib/neo4j/bin/neo4j-admin /var/lib/neo4j/bin/neo4j-admin
COPY --from=graphdb /data /var/lib/neo4j/data
COPY --from=graphdb /data/neo4j-init.sh /data/neo4j-init.sh
COPY --from=graphdb /var/lib/neo4j/conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY --from=graphdb /docker-entrypoint.sh /neo4j-entrypoint.sh

COPY ./wait-for.sh /wait-for.sh

RUN useradd neo4j
EXPOSE 7474 7687 8983 3306
ARG NEO4J_USER=neo4j
ENV NEO4J_USER=$NEO4J_USER
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_PASSWORD=$NEO4J_PASSWORD
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
ENV MYSQL_ROOT_PASSWORD=root
# Neo4j extension script setting.
ENV EXTENSION_SCRIPT=/data/neo4j-init.sh
ENV NEO4J_EDITION=community
RUN ln -s /var/lib/neo4j/conf /conf
# RUN ls -lht /data
# RUN ls -lht /neo4j-data
# RUN ls -lht /diagram-converter/
# RUN env
WORKDIR /
COPY ./generate_diagrams.sh /diagram-converter/generate_diagrams.sh
# neo4j-entrypoint expects su-exec, but there doesn't seem to be a package for that. gosu should be able to do the same thing.
# The sed line below is to make Java more compatible with MySQL 5.7 because I can't seem to get MySQL 5.7 working with TLSv1.2
RUN apt-get update && apt-get install software-properties-common -y -qq \
  && apt-add-repository 'deb http://security.debian.org/debian-security stretch/updates main' \
  && mkdir -p /usr/share/man/man1 && \
  apt-get update && apt-get install gosu openjdk-8-jdk-headless openjdk-8-jre-headless netcat -y -qq \
  && ln -s  $(which gosu) /bin/su-exec \
  && mkdir /diagrams \
  && sed -i 's/\(jdk\.tls\.disabledAlgorithms=.*\)\(TLSv1, TLSv1.1,\)\(.*\)/\1\3/g' /etc/java-8-openjdk/security/java.security \
  && chmod a+x /diagram-converter/generate_diagrams.sh && /diagram-converter/generate_diagrams.sh

# Ok, now that diagrams are generated, maybe we should rebase on something smaller and only copy over what we need.
FROM alpine:3.8
COPY --from=diagrambuilder /diagrams /diagrams
COPY --from=diagrambuilder /diagram-converter/logs/ /diagram-converter-logs
COPY --from=diagrambuilder /diagram-converter/reports/ /diagram-converter-reports
RUN ls /diagrams | wc -l
