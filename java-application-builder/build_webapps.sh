#! /bin/bash
# Build the container - this also builds the applications.
docker build -t reactome-app-builder  -f buildApps.dockerfile .
# Copy the webapps to the shared directory ./webapps
set -x
docker run -it --name=java-webapp-builder --rm -v $(pwd)/webapps:/webapps \
	-v $(pwd)/Pathway-Exchange-pom.xml:/gitroot/Pathway-Exchange/pom.xml \
	-v $(pwd)/RESTfulAPI-pom.xml:/gitroot/RESTfulAPI/pom.xml \
	-v $(pwd)/m2-cache:/root/.m2 \
	reactome-app-builder \
	/bin/bash  -c "$(cat ./maven_builds.sh)"
set +x
