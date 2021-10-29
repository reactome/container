ARG RELEASE_VERSION=Release78
FROM maven:3.6.3-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=master
RUN mkdir -p /gitroot
WORKDIR /gitroot
# master fails when interacting with neo4j, for some reason.
# ENV ANALYSIS_CORE_VERSION=386fd461c2c702e574ad178f8995f3a8a7390166
ENV ANALYSIS_CORE_VERSION=00b0bb611a6ef8892e07a91745464de328610580
RUN git clone https://github.com/reactome/analysis-core.git && \
	cd analysis-core && git checkout $ANALYSIS_CORE_VERSION && \
	cd /gitroot/analysis-core && \
	mvn --no-transfer-progress clean compile package -DskipTests && \
	mkdir -p /analysis-core && \
	mkdir /applications && \
	cp ./target/analysis-core-jar-with-dependencies.jar /applications/analysis-core-jar-with-dependencies.jar

# Now, rebase on the Reactome Neo4j image
FROM reactome/graphdb:$RELEASE_VERSION as analysiscorebuilder
COPY --from=builder /applications/analysis-core-jar-with-dependencies.jar /applications/analysis-core-jar-with-dependencies.jar
ARG NEO4J_USER=neo4j
ENV NEO4J_USER=$NEO4J_USER
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_PASSWORD=$NEO4J_PASSWORD
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
# Neo4j extension script setting
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
# TODO: better name for script outside of container
COPY ./entrypoint.sh /build_analysis_core.sh
RUN chmod a+x /build_analysis_core.sh
COPY ./wait-for.sh /wait-for.sh
RUN apt-get update && apt-get install curl -y && \
	mkdir /output && \
	/build_analysis_core.sh
# Switch to alpine and then copy over the data since we don't need anything else at this point.
FROM alpine:3.8
COPY --from=analysiscorebuilder /output/analysis.bin /output/analysis.bin
