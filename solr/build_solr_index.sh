#! /bin/bash

# cat /etc/passwd
# echo "currently runnin as user: $USER"
# ls -lht /var/lib/neo4j/bin
PATH=$PATH:/var/lib/neo4j/bin/
# env

cd /var/lib/neo4j
bash /neo4j-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90 && bash /wait-for.sh localhost:7474 -t 90
cd /opt/docker-solr/scripts/
# su-exec solr solr start
# su-exec solr solr create -c reactome -d /custom-solr-conf/

# su-exec solr ./docker-entrypoint.sh solr-precreate reactome /custom-solr-conf/ &
# su-exec solr /opt/docker-solr/scripts/wait-for-solr.sh
# Now, copy the config from the source repo
# ls -lht  /custom-solr-conf/
# ls -lht /opt/solr/server/solr/mycores/
# ls -lht /opt/solr/server/solr/
# cp /custom-solr-conf/prefixstopwords.txt /opt/solr/server/solr/mycores/reactome/conf/prefixstopwords.txt
# cp /custom-solr-conf/schema.xml /opt/solr/server/solr/mycores/reactome/conf/schema.xml
# cp /custom-solr-conf/solrconfig.xml /opt/solr/server/solr/mycores/reactome/conf/solrconfig.xml
# cp /custom-solr-conf/stopwords.txt /opt/solr/server/solr/mycores/reactome/conf/stopwords.txt
# ls -lht /opt/solr/server/solr/mycores/
# start solr
# su-exec --help
su-exec solr solr start
echo "Waiting for solr..."
# su-exec solr ./docker-entrypoint.sh start-local-solr
# su-exec solr /opt/docker-solr/scripts/wait-for-solr.sh
bash /wait-for.sh localhost:8983 -t 90
echo "Now building the solr index."
# print Java version info
java -version
# run the indexer.
# set -x
java -jar /indexer/Indexer-jar-with-dependencies.jar \
  -a localhost -b 7474 -c $NEO4J_USER -d $NEO4J_PASSWORD \
  -e  http://localhost:8983/solr -o reactome -f "solr" -g "solr" \
  -i localhost -j 25 -k dummy -n
