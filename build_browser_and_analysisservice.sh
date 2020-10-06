#! /bin/bash

RELEASE_VERSION=Release73
NEO4J_USER=neo4j
NEO4J_PASSWORD=n304j

STARTING_DIR=$(pwd)
set -e
# echo -e "===\nBuilding graph database...\n"
# cd $STARTING_DIR/neo4j
# docker build -t reactome/graphdb:$RELEASE_VERSION \
# 	--build-arg NEO4J_USER=$NEO4J_USER \
# 	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
# 	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
# 	--build-arg GRAPHDB_LOCATION=https://reactome.org/download/current/reactome.graphdb.tgz \
# 	-f ./neo4j_stand-alone.dockerfile .

# echo -e "===\nCreating the Analyis file...\n"
# cd $STARTING_DIR/analysis-core
# docker build -t reactome/analysis-core \
# 	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
# 	--build-arg NEO4J_USER=$NEO4J_USER \
# 	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
# 	-f analysis-core.dockerfile .
#
# echo -e "===\nGenerating Fireworks files...\n"
# cd $STARTING_DIR/fireworks-generator
# docker build -t reactome/fireworks-generator \
# 	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
# 	--build-arg NEO4J_USER=$NEO4J_USER \
# 	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
# 	-f fireworks-generator.dockerfile .

echo -e "===\nBuilding analysis-service + PathwayBrowser image...\n"
cd $STARTING_DIR/pathway-browser
docker build -t reactome/analysis-service-and-pwb \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f pathway-browser.dockerfile .

cd $STARTING_DIR

echo -e "===\nImages built: "
# We are building 4 "reactome" images, so lets display them
docker images | grep "reactome" | head -n 4

echo -e "Now you can run the stand-alone content-service like this:\n'docker run --name reactome-analysis-service -p 8080:8080 reactome/stand-alone-analysis-service:${RELEASE_VERSION}'"
set +e