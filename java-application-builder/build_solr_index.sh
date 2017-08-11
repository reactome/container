#! /bin/bash

# Run the indexer in a container. Solr and neo4j must already be up and running and a
# part of the network "javaapplicationbuilder_solr-index-builder"

echo "Running indexer..."

docker run  -v $(pwd)/webapps/interactors.db:/interactors.db \
	-v $(pwd)/wait-for.sh:/wait-for.sh \
	-v $(pwd)/webapps/Indexer-jar-with-dependencies.jar:/Indexer-jar-with-dependencies.jar \
	-v $(pwd)/logs:/gitroot/search-indexer/logs \
	--network=javaapplicationbuilder_solr-index-builder \
	reactome-app-builder \
	bash -c "/wait-for.sh neo4j:7687 -t 360 && /wait-for.sh solr:8983 -t 360 && java -jar /Indexer-jar-with-dependencies.jar \
	-a neo4j -b 7474 -c neo4j -d neo4j-password -e  http://solr:8983/solr/reactome -f \"\" -g \"\" \
	-h /interactors.db \
	-i localhost -j 25 -k dummy "


# java -jar /Indexer-jar-with-dependencies.jar \
# 	-a neo4j -b 7474 -c neo4j -d neo4j-password \
# 	-e  http://solr:8983/solr/reactome -f "" -g "" \
# 	-h /interactors.db \
# 	-i localhost -j 25 -k dummy
