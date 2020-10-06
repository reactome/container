ARG RELEASE_VERSION=Release74
FROM maven:3.6.3-jdk-8 AS builder

RUN mkdir /gitroot
# The commit ID for the "speed-up" version of search-indexer. Runs faster than normal, by using multiple threads.
ENV INDEXER_VERSION=master
WORKDIR /gitroot/
RUN mkdir /gitroot/search-indexer
RUN git clone https://github.com/reactome/search-indexer.git && \
	cd /gitroot/search-indexer && \
	git checkout $INDEXER_VERSION && \
	sed -i -e 's/http:\/\/repo1/https:\/\/repo1/g' pom.xml && \
	sed -i -e 's/http:\/\/repo/https:\/\/repo/g' pom.xml && \
	mvn --no-transfer-progress clean compile package -DskipTests && ls -lht ./target && \
	mkdir /indexer && \
	cp /gitroot/search-indexer/target/Indexer-jar-with-dependencies.jar /indexer/Indexer-jar-with-dependencies.jar && \
	rm -rf ~/.m2

# We'll need to get stuff from graphdb
FROM reactome/graphdb:${RELEASE_VERSION} as graphdb
# final base images is solr
FROM solr:6.6.5-alpine
USER root
RUN mkdir /indexer
# bring the indexer from the "builder" image.
COPY --from=builder /indexer/Indexer-jar-with-dependencies.jar /indexer/Indexer-jar-with-dependencies.jar
COPY --from=graphdb /docker-entrypoint.sh /neo4j-entrypoint.sh
COPY --from=graphdb /data /data
COPY --from=graphdb /var/lib/neo4j /var/lib/neo4j
COPY --from=graphdb /var/lib/neo4j/bin/neo4j-admin /var/lib/neo4j/bin/neo4j-admin
COPY --from=graphdb /var/lib/neo4j/conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY --from=builder  /gitroot/search-indexer/solr-conf/reactome/ /custom-solr-conf/


# copy neo4j



# RUN ls -lht /custom-solr-conf/

# setup for neo4j

RUN ls -lht /var/lib/neo4j/conf/neo4j.conf
# Args for neo4j user/password - I'm not sure if ENV variables get inherited
# when I do "FROM ..." but this way, a user can redefine them for this
# particular build.
ARG NEO4J_USER=neo4j
ENV NEO4J_USER=$NEO4J_USER
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_PASSWORD=$NEO4J_PASSWORD
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD



# we'll need netcat so that solr can "wait-for" neo4j to start. parallel is to
# speed up the download of Icon XML Metadata files.
RUN apk add parallel netcat-openbsd su-exec shadow tini

# we'll need Icon XML files.
COPY ./get_icon_xml_files.sh /get_icon_xml_files.sh
# RUN bash /get_icon_xml_files.sh

RUN mkdir /indexer/logs && chmod a+rw /indexer/logs

COPY ./wait-for.sh /wait-for.sh
# The Neo4j entrypoint script will be the entrypoint, and then we will explicitly
# invoke the solr entrypoint before running the indexer.
# ENTRYPOINT ["/data/neo4j-init.sh"]
#Entry point:
# docker-entrypoint.sh solr-precreate reactome
# The actual command to run:
# java -jar /indexer/Indexer-jar-with-dependencies.jar \
#   -a neo4j -b 7474 -c $NEO4J_USER -d $NEO4J_PASSWORD \
#   -e  http://localhost:8983/solr/reactome -f "" -g "" \
#   -i localhost -j 25 -k dummy
RUN useradd neo4j
EXPOSE 7474 7687 8983
ENV NEO4J_EDITION=community
RUN ln -s /var/lib/neo4j/conf /conf
WORKDIR /

# We'll also need EHLD files
# RUN mkdir /tmp/ehld
ADD https://reactome.org/download/current/ehlds.tgz /tmp/ehld.tgz
USER root
RUN chmod a+rw /tmp && chmod a+rw /tmp/ehld.tgz
# RUN cd /tmp/ && tar -zxf ehld.tgz && echo "Files in /tmp/ehld " && ls ehld/* | wc -l

USER solr
# Create a new core.
RUN solr start && solr create -c reactome -p 8983 -d /custom-solr-conf/ && solr stop
COPY ./build_solr_index.sh /build_solr_index.sh
USER root
RUN chmod a+x /build_solr_index.sh && chown -R neo4j:neo4j /var/lib/neo4j && chown -R neo4j:neo4j /data && chmod u+s /sbin/su-exec && mkdir /logs && chmod a+rw /logs
# Give the neo4j user access to the same stuff the solr user has.
# RUN usermod -a solr -G neo4j
USER neo4j
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
RUN /build_solr_index.sh
USER root
RUN chmod a+rw /opt/solr/server/solr/reactome/data/index/write.lock && \
  chmod a+rw -R /opt/solr/server/logs && \
  chmod a+rw /opt/solr/server/solr/reactome/data/tlog/*
USER solr
