ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ARG RELEASE_VERSION=R71
FROM maven:3.6.3-jdk-8 AS builder

RUN mkdir /gitroot
ENV GRAPH_IMPORTER_VERSION=master
WORKDIR /gitroot/

RUN git clone https://github.com/reactome/graph-importer.git
WORKDIR /gitroot/graph-importer
RUN git checkout $GRAPH_IMPORTER_VERSION && \
	mvn --no-transfer-progress clean compile package -DskipTests && ls -lht ./target && \
	mkdir /graph-importer && cp /gitroot/graph-importer/target/GraphImporter-jar-with-dependencies.jar  /graph-importer/GraphImporter-jar-with-dependencies.jar

# Add MySQL layer

FROM reactome/reactome-mysql:${RELEASE_VERSION} as relationaldb
ENV MYSQL_ROOT_PASSWORD=root
COPY --from=builder /graph-importer/GraphImporter-jar-with-dependencies.jar /graph-importer/GraphImporter-jar-with-dependencies.jar
WORKDIR /
RUN mkdir /graphdb && \
	mkdir -p /usr/share/man/man1
COPY ./generate_graphdb.sh /generate_graphdb.sh
COPY ./wait-for.sh /wait-for.sh
RUN chmod a+x /generate_graphdb.sh && \
	apt-get update && apt-get install gosu openjdk-8-jdk-headless openjdk-8-jre-headless netcat -y && apt-get autoremove && \
	/generate_graphdb.sh
RUN chmod a+rw -R /graphdb
# Now re-base on neo4j
FROM neo4j:3.5.14
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
LABEL maintainer=solomon.shorser@oicr.on.ca
LABEL ReleaseVersion=$RELEASE_VERSION
EXPOSE 7474 7473 7687
COPY --from=relationaldb /graphdb /var/lib/neo4j/data/databases/reactome.graphdb
# Let's keep a copy of the graph-importer's logs.
COPY --from=relationaldb /graph-importer/graph-importer-logs.tgz /graph-importer-logs.tgz
USER root
COPY ./conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
RUN touch /data/neo4j-import-done.flag \
	&& chown -R neo4j:neo4j /data/databases/reactome.graphdb \
	&& chown neo4j:neo4j /var/lib/neo4j/conf/neo4j.conf \
	&& chmod u+rw /var/lib/neo4j/conf/neo4j.conf \
	&& chmod a+rw -R /data/databases/* \
	&& chmod a+rw -R /data/*
# USER neo4j
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
COPY ./neo4j-init.sh /data/neo4j-init.sh
