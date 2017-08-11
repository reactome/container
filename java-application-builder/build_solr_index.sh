#! /bin/bash

# Meant to be run inside a container with access to a neo4j container and a solr container

echo "Running indexer..."
java -jar /Indexer-jar-with-dependencies.jar \
	-a neo4j -b 7474 -c neo4j -d neo4j-password \
	-e  http://solr:8983/solr/reactome -f "" -g "" \
	-h /interactors.db \
	-i localhost -j 25 -k dummy
