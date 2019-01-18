#! /bin/bash
PATH=$PATH:/var/lib/neo4j/bin/

# Start Neo4j
cd /var/lib/neo4j
bash /docker-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90 && bash /wait-for.sh localhost:7474 -t 90

time java -jar /applications/analysis-core-jar-with-dependencies.jar -h localhost -p 7474 -u $NEO4J_USER -k $NEO4J_PASSWORD -o /output/analysis.bin -t -v
