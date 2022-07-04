#! /bin/bash

RELEASE_VERSION=Release77
NEO4J_USER=neo4j
NEO4J_PASSWORD=neo4j-password

STARTING_DIR=$(pwd)
set -e
echo -e "===\nBuilding graph database...\n"
cd $STARTING_DIR/neo4j
docker build -t reactome/graphdb:$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg GRAPHDB_LOCATION=./reactome.graphdb.tgz \
	-f ./neo4j_stand-alone.dockerfile .

echo -e "===\nCreating the Analyis file...\n"
cd $STARTING_DIR/analysis-core
docker build -t reactome/analysis-core:${RELEASE_VERSION} \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f analysis-core.dockerfile .

echo -e "===\nGenerating Fireworks files...\n"
cd $STARTING_DIR/fireworks-generator
docker build -t reactome/fireworks-generator:${RELEASE_VERSION} \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f fireworks-generator.dockerfile .

echo -e "===\nBuilding relational database...\n"
cd $STARTING_DIR/mysql
docker build -t reactome/reactome-mysql:$RELEASE_VERSION \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f mysql.dockerfile .

echo -e "===\nGenerating diagram files...\n"
cd $STARTING_DIR/diagram-generator
docker build -t reactome/diagram-generator:${RELEASE_VERSION} \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	-f diagram-generator.dockerfile .

# You will need to generate a Personal Access Token to access the Reacfoam repo. Save it in a file "github.token"
# Make sure you give the token the permissions: repo (repo:status, repo_deployment, public_repo, repo:invite, security_events) and read:repo_hook
cd $STARTING_DIR/pathway-browser
set -x
GITHUB_TOKEN=$(cat github.token)
echo -e "===\nBuilding analysis-service + PathwayBrowser image...\n"
docker build -t reactome/analysis-service-and-pwb:${RELEASE_VERSION} \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg GITHUB_TOKEN=$GITHUB_TOKEN \
	-f pathway-browser.dockerfile .
set +x
cd $STARTING_DIR

echo -e "===\nImages built: "
# We are building 4 "reactome" images, so lets display them
docker images | grep "reactome" | head -n 4

echo -e "Now you can run the stand-alone content-service like this:\n'docker run --name reactome-pwb-and-analysis-service -p 8080:8080 reactome/analysis-service-and-pwb:${RELEASE_VERSION}'"
set +e
