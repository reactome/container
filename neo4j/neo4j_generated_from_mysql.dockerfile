ARG RELEASE_VERSION=R67
FROM maven:3.6.0-jdk-8 AS builder

RUN mkdir /gitroot
ENV GRAPH_IMPORTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/graph-importer.git
WORKDIR /gitroot/graph-importer
RUN git checkout $GRAPH_IMPORTER_VERSION
RUN mvn clean compile package -DskipTests && ls -lht ./target
RUN mkdir /graph-importer && cp /gitroot/graph-importer/target/GraphImporter-jar-with-dependencies.jar  /graph-importer/GraphImporter-jar-with-dependencies.jar

# Add MySQL layer

FROM reactome/reactome-mysql:${RELEASE_VERSION} as relationaldb
COPY --from=builder /graph-importer/GraphImporter-jar-with-dependencies.jar /graph-importer/GraphImporter-jar-with-dependencies.jar
WORKDIR /
RUN mkdir -p /usr/share/man/man1
RUN apt-get update && apt-get install gosu openjdk-8-jdk-headless openjdk-8-jre-headless netcat -y
RUN mkdir /graphdb
COPY ./generate_graphdb.sh /generate_graphdb.sh
RUN chmod a+x /generate_graphdb.sh
ENV MYSQL_ROOT_PASSWORD=root
COPY ./wait-for.sh /wait-for.sh
RUN /generate_graphdb.sh

# Now re-base on neo4j
FROM neo4j:3.4.9
LABEL maintainer=solomon.shorser@oicr.on.ca
LABEL ReleaseVersion=$RELEASE_VERSION
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
EXPOSE 7474 7473 7687
COPY --from=relationaldb /graphdb /var/lib/neo4j/data/databases/reactome.graphdb
RUN touch /data/neo4j-import-done.flag
COPY ./conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
# COPY ./neo4j-init.sh /data/neo4j-init.sh
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
