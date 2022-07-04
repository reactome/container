ARG RELEASE_VERSION=Release74

FROM maven:3.6.3-jdk-11 AS builder
# Issues with Java 11: cannot find javax.annotation
RUN mkdir /gitroot
ENV FIREWORKS_SRC_VERSION=1da5741727594bb07e445c32e417aade89f1a1f4

WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/fireworks-layout.git
WORKDIR /gitroot/fireworks-layout
RUN git checkout $FIREWORKS_SRC_VERSION
# Include javax.annotation-api for Java 11
RUN sed -i 's/<dependencies>/<dependencies>\n<dependency>\n<groupId>javax.annotation<\/groupId><artifactId>javax.annotation-api<\/artifactId><version>1.3.1<\/version><\/dependency>/g' pom.xml
RUN mvn --no-transfer-progress clean compile package -DskipTests && ls -lht ./target

# Now, rebase on the Reactome Neo4j image
FROM reactome/graphdb:${RELEASE_VERSION} as graphdb

ARG NEO4J_USER=neo4j
ENV NEO4J_USER=$NEO4J_USER
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_PASSWORD=$NEO4J_PASSWORD
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
# Neo4j extension script setting
ENV EXTENSION_SCRIPT /data/neo4j-init.sh

COPY --from=builder /gitroot/fireworks-layout/target/fireworks-jar-with-dependencies.jar /fireworks/fireworks.jar
COPY --from=builder /gitroot/fireworks-layout/config /fireworks/config
COPY ./wait-for.sh /wait-for.sh
COPY ./run_fireworks_generator.sh /run_fireworks_generator.sh

RUN chmod a+x /run_fireworks_generator.sh
RUN mkdir /fireworks-json-files
RUN /run_fireworks_generator.sh

FROM alpine:3.8
COPY --from=graphdb /fireworks-json-files /fireworks-json-files
COPY --from=graphdb /fireworks/fireworks.log /fireworks/fireworks.log
RUN ls -lht /fireworks-json-files
