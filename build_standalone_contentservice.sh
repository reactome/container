#! /bin/bash

RELEASE_VERSION=Release72
NEO4J_USER=neo4j
NEO4J_PASSWORD=n304j

STARTING_DIR=$(pwd)
set -e
echo -e "===\nBuilding graph database...\n"
cd $STARTING_DIR/neo4j
docker build -t reactome/graphdb:$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg GRAPHDB_LOCATION=https://reactome.org/download/current/reactome.graphdb.tgz \
	-f ./neo4j_stand-alone.dockerfile .

echo -e "===\nBuilding solr index...\n"
cd $STARTING_DIR/solr
docker build -t reactome/solr:$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f index-builder.dockerfile .

echo -e "===\nBuilding relational database...\n"
cd $STARTING_DIR/mysql
docker build -t reactome/reactome-mysql:$RELEASE_VERSION \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f mysql.dockerfile .

echo -e "===\nGenerating diagram files...\n"
cd $STARTING_DIR/diagram-generator
docker build -t reactome/diagram-generator \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f diagram-generator.dockerfile .

echo -e "===\nBuilding content-service image...\n"
cd $STARTING_DIR/stand-alone-content-service
docker build -t reactome/stand-alone-content-service \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f content-service.dockerfile .

cd $STARTING_DIR/

echo -e "===\nImages built: "
# We are building 4 "reactome" images, so lets display them
docker images | grep "reactome" | head -n 4

echo -e "Now you can run the stand-alone content-service like this:\n'docker run --name reactome-content-service -p 8080:8080 reactome/stand-alone-content-service:Release71'"
set +e
