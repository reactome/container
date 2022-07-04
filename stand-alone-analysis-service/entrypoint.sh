#! /bin/bash
PATH=$PATH:/var/lib/neo4j/bin/:/opt/solr/bin:/opt/docker-solr/scripts

ln -s /var/lib/neo4j/conf /conf
mkdir -p /var/lib/neo4j/certificates && chown neo4j:neo4j /var/lib/neo4j/certificates

chown neo4j:neo4j /logs
# Start Neo4j
cd /var/lib/neo4j
bash /neo4j-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90 && bash /wait-for.sh localhost:7474 -t 90

echo "Starting tomcat..."
# Now that Neo4j has been started, we can run tomcat
cd /usr/local/tomcat
catalina.sh run
