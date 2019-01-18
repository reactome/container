FROM maven:3.6.0-jdk-8 AS builder

RUN mkdir /gitroot
ENV DIAGRAM_CONVERTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/diagram-converter.git
WORKDIR /gitroot/diagram-converter
RUN git checkout $DIAGRAM_CONVERTER_VERSION
RUN mvn clean compile package -DskipTests && ls -lht ./target
RUN mkdir /diagram-converter && cp /gitroot/diagram-converter/target/diagram-converter-jar-with-dependencies.jar /diagram-converter/diagram-converter-jar-with-dependencies.jar

# Now, rebase on the Reactome Neo4j image
FROM reactome/reactome-neo4j:R-67 as graphdb
# RUN mkdir /diagram-converter
# bring the indexer from the prior image.
# COPY --from=builder /diagram-converter/diagram-converter-jar-with-dependencies.jar /diagram-converter/diagram-converter-jar-with-dependencies.jar

# Add MySQL layer, but name it "diagrambuilder" since this is where we will actually create the diagrams.
FROM reactome/reactome-mysql:R67 as diagrambuilder
# RUN mkdir /diagram-converter
COPY --from=builder /diagram-converter/diagram-converter-jar-with-dependencies.jar /diagram-converter/diagram-converter-jar-with-dependencies.jar

# USER root
# copy neo4j stuff into this image
# COPY --from=graphdb /data /neo4j-data
COPY --from=graphdb /var/lib/neo4j /var/lib/neo4j
COPY --from=graphdb /var/lib/neo4j/bin/neo4j-admin /var/lib/neo4j/bin/neo4j-admin
COPY --from=graphdb /data /var/lib/neo4j/data

COPY --from=graphdb /data/neo4j-init.sh /data/neo4j-init.sh
COPY --from=graphdb /var/lib/neo4j/conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
# RUN ls -lht /var/lib/neo4j/conf/neo4j.conf
# Args for neo4j user/password - I'm not sure if ENV variables get inherited
# when I do "FROM ..." but this way, a user can redefine them for this
# particular build.


COPY --from=graphdb /docker-entrypoint.sh /neo4j-entrypoint.sh
# COPY --from=graphdb /indexer/Indexer-jar-with-dependencies.jar /indexer/Indexer-jar-with-dependencies.jar
# we'll need netcat so that solr can "wait-for" neo4j to start
# RUN mkdir /apk
# WORKDIR /apk
# RUN wget https://github.com/alpinelinux/apk-tools/releases/download/v2.10.3/apk-tools-2.10.3-x86-linux.tar.gz
# RUN tar -zxvf apk-tools-2.10.3-x86-linux.tar.gz
# RUN apk-tools-2.10.3/apk --help
# RUN apk-tools-2.10.3/apk index
# RUN apk-tools-2.10.3/apk update && apk-tools-2.10.3/apk add netcat su-exec shadow tini
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
RUN ls -lht /data
# RUN ls -lht /neo4j-data
RUN ls -lht /diagram-converter/
RUN env
WORKDIR /
RUN mkdir -p /usr/share/man/man1
RUN apt-get update && apt-get install gosu openjdk-8-jdk-headless openjdk-8-jre-headless netcat -y
# neo4j-entrypoint expects su-exec, but there doesn't seem to be a package for that. gosu should be able to do the same thing.
RUN ln -s  $(which gosu) /bin/su-exec
# RUN apt-get install -y --no-install-recommends software-properties-common
# RUN add-apt-repository -y ppa:openjdk-r/ppa

# RUN update-alternatives --config java
# RUN update-alternatives --config javac

# RUN  /neo4j-entrypoint.sh ls
RUN mkdir /diagrams
COPY ./generate_diagrams.sh /diagram-converter/generate_diagrams.sh
RUN chmod a+x /diagram-converter/generate_diagrams.sh && /diagram-converter/generate_diagrams.sh
# RUN ls -lht /diagrams | head && du -hscx /diagrams

# Ok, now that diagrams are generated, maybe we should rebase on something smaller and only copy over what we need.
FROM alpine:3.8
COPY --from=diagrambuilder /diagrams /diagrams
COPY --from=diagrambuilder /diagram-converter/log /diagram-converter.log
