FROM maven:3.5-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=master
RUN mkdir -p /gitroot
WORKDIR /gitroot

ENV ANALYSIS_CORE_VERSION=master
RUN git clone https://github.com/reactome/analysis-core.git
RUN cd analysis-core && git checkout $ANALYSIS_CORE_VERSION
WORKDIR /gitroot/analysis-core
RUN mvn clean compile package
RUN mkdir -p /analysis-core
RUN ls -lht ./target

RUN mkdir /applications
RUN cp ./target/analysis-core-jar-with-dependencies.jar /applications/analysis-core-jar-with-dependencies.jar

# Re-base on neo4j
# FROM neo4j:3.4.9
# RUN mkdir -p /applications
# COPY --from=builder /applications/analysis-core-jar-with-dependencies.jar /applications/analysis-core-jar-with-dependencies.jar
# RUN apk add curl
# # create a conf file - user must mount graph database ase "reactome.graphdb"
# RUN echo -e "dbms.active_database=reactome.graphdb\ndbms.allow_format_migration=true\ndbms.security.auth_enabled=false" > /var/lib/neo4j/conf/neo4j.conf
# COPY ./entrypoint.sh /start_and_ping_neo4j.sh
# RUN chmod a+x /start_and_ping_neo4j.sh
# RUN mkdir -p /output/ && chmod a+rw /output
# # TODO: Have the final step build the analysis core so that it can be copied directly by other containers.
# # run as: docker run --name run-analysis-core --rm -p 7474:7474 -p 7687:7687 -v $(pwd)/output:/output -v $(pwd)/reactome.graphdb.v66:/var/lib/neo4j/data/databases/reactome.graphdb reactome_analysis_core /bin/bash -c "/start_and_ping_neo4j.sh"


# Now, rebase on the Reactome Neo4j image
FROM reactome/reactome-neo4j:R-67 as analysiscorebuilder
COPY --from=builder /applications/analysis-core-jar-with-dependencies.jar /applications/analysis-core-jar-with-dependencies.jar
ARG NEO4J_USER=neo4j
ENV NEO4J_USER=$NEO4J_USER
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_PASSWORD=$NEO4J_PASSWORD
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
# Neo4j extension script setting
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
RUN apk add curl
# TODO: better name for script outside of container
COPY ./entrypoint.sh /build_analysis_core.sh
RUN chmod a+x /build_analysis_core.sh
COPY ./wait-for.sh /wait-for.sh
RUN mkdir /output
RUN /build_analysis_core.sh
# Switch to alpine and then copy over the data since we don't need anything else at this point.
FROM alpine:3.8
COPY --from=analysiscorebuilder /output/analysis.bin /output/analysis.bin
