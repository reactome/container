#! /bin/bash

PATH=$PATH:/var/lib/neo4j/bin/

# Start Neo4j
cd /var/lib/neo4j
bash /docker-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90 && bash /wait-for.sh localhost:7474 -t 90
env
# Generate the fireworks files for all species
echo "Running Fireworks generator..."
cd /fireworks
java -jar fireworks.jar \
	-h localhost \
	-p 7474 \
	-u $NEO4J_USER \
	-k $NEO4J_PASSWORD \
	-f ./config \
	-o /fireworks-json-files | grep -v DEBUG > fireworks.log

tail fireworks.log

ls -lht /fireworks-json-files
