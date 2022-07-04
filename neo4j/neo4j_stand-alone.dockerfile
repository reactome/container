# This is for running the Reactome graph database in a stand-alone Neo4j docker container.
# This image will be based on the "neo4j" image, with Reactome data built in.
#
# You can pass in build arguments for neo4j username and password, location of graph database file to use, and also for release number.
#
# With build args:
#	`docker build -t reactome/graphdb:ReleaseXX \
#	  --build-arg NEO4J_USER=neo4j \
#	  --build-arg NEO4J_PASSWORD=xxxx \
#	  --build-arg ReleaseVersion=ReleaseXX \
#	  -f ./neo4j_stand-alone.dockerfile .`
#
# Specifying location of graph database:
#	`docker build -t reactome/graphdb:ReleaseXX \
#	  --build-arg GRAPHDB_LOCATION=./reactome-ReleaseXX.graphdb.tgz \
#	  --build-arg NEO4J_USER=neo4j \
#	  --build-arg NEO4J_PASSWORD=xxxx \
#	  --build-arg ReleaseVersion=ReleaseXX \
#	  -f ./neo4j_stand-alone.dockerfile .`
#
# To run this, execute: `docker run --rm -p 7474:7474 -p 7687:7687 --name reactome-graphdb reactome/graphdb:ReleaseXX`
# The Neo4j web interface will be available at http://localhost:7474
FROM neo4j:3.5.25
# RELEASE_VERSION should be given when building the image.
ARG RELEASE_VERSION=Release75
# If you want to override user/password at RUN time, do it as 'docker run -e NEO4J_AUTH="neo4j/PASSWORD" ... reactome/graphdb'
ARG NEO4J_USER=neo4j
ARG NEO4J_PASSWORD=neo4j-password
ARG GRAPHDB_LOCATION=./reactome-${RELEASE_VERSION}.graphdb.tgz
ENV NEO4J_AUTH $NEO4J_USER/$NEO4J_PASSWORD
ENV EXTENSION_SCRIPT /data/neo4j-init.sh

LABEL maintainer=solomon.shorser@oicr.on.ca
LABEL ReleaseVersion=$RELEASE_VERSION
EXPOSE 7474 7473 7687
# default is a local, zipped copy of the Reactome graph database.
COPY ${GRAPHDB_LOCATION} /var/lib/neo4j/data/databases/reactome.graphdb.tgz
COPY ./conf/neo4j.conf /var/lib/neo4j/conf/neo4j.conf
COPY ./neo4j-init.sh /data/neo4j-init.sh

# While the image built by neo4j_generated_from_mysql.dockerfile is preferred,
# it is sometimes useful/faster to use the pre-built graph database found on reactome.org's download page.
