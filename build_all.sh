#! /bin/bash

# simple script to build ALL of the images necessary to run Reactome in docker containers.

#TODO: get the Release version as well as Neo4j username/password from a file.
RELEASE_VERSION=R71
NEO4J_USER=neo4j
NEO4J_PASSWORD=n304j
set -e
# the MySQL database is the first piece that must be built - solr, neo4j, analysis-core,
# diagrams generator, fireworks generator depend on it.
echo "Building the MySQL image."
cd ./mysql
docker build -t reactome/reactome-mysql:$RELEASE_VERSION -f mysql.dockerfile .

# Next, we need to create the graph database.
cd ../neo4j
echo "Building the graph database."
docker build -t reactome/graphdb:$RELEASE_VERSION \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f neo4j_generated_from_mysql.dockerfile .

# Now, we can build everyting else!

cd ../analysis-core
echo "Generating the analysis.bin file."
docker build -t reactome/analysis-core \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f analysis-core.dockerfile .

cd ../diagram-generator
echo "Generating the diagram JSON files."
docker build -t reactome/diagram-generator \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f diagram-generator.dockerfile .

cd ../fireworks-generator
echo "Generating the fireworks files."
docker build -t reactome/fireworks-generator \
	--build-arg RELEASE_VERSION=$RELEASE_VERSION \
	--build-arg NEO4J_USER=$NEO4J_USER \
	--build-arg NEO4J_PASSWORD=$NEO4J_PASSWORD \
	-f fireworks-generator.dockerfile .

# Build all of the Java web applications.
# Right now, we always build from master because no repos are have release tags.
# Hopefully that will change in the future...
# $ANALYSIS_SERVICE_VERSION=
cd ../tomcat
echo "Building Java applications!"
echo "Building AnalysisService"
docker build -t reactome/analysisservice -f AnalysisService.dockerfile .
echo "Building ContentService"
docker build -t reactome/contentservice -f ContentService.dockerfile .
echo "Building data-content"
docker build -t reactome/datacontent -f data-content.dockerfile .
echo "Building DiagramJs"
docker build -t reactome/diagramjs -f DiagramJs.dockerfile .
echo "Building FireworksJs"
docker build -t reactome/fireworksjs -f FireworksJs.dockerfile .
echo "Building PathwayBrowser"
docker build -t reactome/pathwaybrowser -f PathwayBrowser.dockerfile .
echo "Building ReactomeRESTfulAPI"
docker build -t reactome/reactomerestfulapi -f ReactomeRESTfulAPI.dockerfile .
echo "Building experiments-digester"
docker build -t reactome/experiments-digester -f ExperimentDigester.dockerfile .

# Finally, we will build the solr index.
cd ../solr
echo "Building the Solr index"
docker build -t reactome/solr:$RELEASE_VERSION -f index-builder.dockerfile .

# Let's display what was built.
docker images | grep "reactome/"

echo "Building tomcat image"
cd ../tomcat
docker build -t reactome/tomcat -f tomcat.dockerfile .
cd ..
echo "Building remaining joomla-sites image"
docker-compose build joomla-sites
echo "Building MySQL database for Joomla"
docker-compose build mysql-for-joomla
echo "All done. Reactome images:"
# Let's display what was built.
docker images | grep "reactome/"
set +e
