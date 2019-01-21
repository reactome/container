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
ARG RELEASE_VERSION=R67
# Now, rebase on the Reactome Neo4j image
FROM reactome/reactome-neo4j:$RELEASE_VERSION as analysiscorebuilder
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
