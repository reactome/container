# This is for running the Reactome graph database in a stand-alone Neo4j docker container.
# This image will be based on the "neo4j" image, with Reactome data built in.
# To build this, execute: `docker build -t reactome/reactome-neo4j:R62 -f ./neo4j_stand-alone.dockerfile`
# You can pass in build arguments for neo4j username and password, and also for release number.
# To run this, execute: `docker run --rm -p 7474:7474 -p 7687:7687 --name reactome-neo4j reactome/reactome-neo4j:R62`
# With build args: `docker build -t reactome/reactome-neo4j:R-999 --build-arg NEO4J_USER=neo4j --build-arg NEO4J_PASSWORD=xxxx --build-arg ReleaseVersion=999 -f ./neo4j_stand-alone.dockerfile .`
FROM neo4j:3.4.9
LABEL maintainer=solomon.shorser@oicr.on.ca
ARG ReleaseVersion=67
LABEL ReleaseVersion=$ReleaseVersion
ENV EXTENSION_SCRIPT /data/neo4j-init.sh
EXPOSE 7474 7473 7687
# This requires a local, zipped copy of the Reactome graph database.
COPY ./reactome-R$ReleaseVersion.graphdb.tgz /var/lib/neo4j/data/databases/reactome.graphdb.tgz
COPY ./conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY ./neo4j-init.sh /data/neo4j-init.sh
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD

# ...Eventually, this will probably be deprecated in favour of the image built by neo4j_generated_from_mysql.dockerfile
