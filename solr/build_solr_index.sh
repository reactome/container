#! /bin/bash
set -e
PATH=$PATH:/var/lib/neo4j/bin/
# env
echo "Getting icon XML files..."
bash /get_icon_xml_files.sh

cd /tmp/
ls -lht
tar -zxf ehld.tgz
echo "Files in /tmp/ehld "
ls ehld/* | wc -l

cd /var/lib/neo4j
bash /neo4j-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90
bash /wait-for.sh localhost:7474 -t 90
cd /opt/docker-solr/scripts/

# solr start
su-exec solr solr start
echo "Waiting for solr..."


bash /wait-for.sh localhost:8983 -t 90
echo "Now building the solr index..."
cd /indexer

java -version

# run the indexer.
time su-exec root java -jar ./search-indexer-jar-with-dependencies.jar \
  -a localhost -b 7474 -c $NEO4J_USER -d $NEO4J_PASSWORD \
  -e  http://localhost:8983/solr -o reactome -f "solr" -g "solr" \
  -q /tmp/icon-lib -r /tmp/ehld -n true -l true

echo "Tail of log output: "
tail -n 50 /indexer/logs/*
# clean up Neo4j stuff
su-exec root rm -rf /var/lib/neo4j && su-exec root rm -rf /data && su-exec root rm -rf /tmp/icon-lib && su-exec root rm -rf /tmp/ehld*
set +e
