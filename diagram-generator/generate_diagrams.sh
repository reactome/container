#! /bin/bash

PATH=$PATH:/var/lib/neo4j/bin/

# Start Neo4j
cd /var/lib/neo4j
bash /neo4j-entrypoint.sh neo4j &

echo "Waiting for Neo4j..."
bash /wait-for.sh localhost:7687 -t 90 && bash /wait-for.sh localhost:7474 -t 90

# Start MySQL
/usr/local/bin/docker-entrypoint.sh mysqld &
# service mysqld start &
echo "Waiting for MySQL..."
bash /wait-for.sh localhost:3306 -t 90
# If you don't "blank out" the accessibility.properties file, Java
# will eventually crash when it tries to run/access some sort of accessibility-
# related component that I don't think is necessary for generating the diagrams.
echo -e "\n\n" > /etc/java-8-openjdk/accessibility.properties
echo "Running diagram generator..."
# Run the diagram generator
# NOTE: NEO4J_USER and NEO4J_PASSWORD are set in the dockerfile.
# The "| grep -v DEBUG > log" is because loggin config seems to produce a LOT of
# "debug" noise. Mostly from the neo4j and spring libraries.
cd /diagram-converter/
java -jar /diagram-converter/diagram-converter-jar-with-dependencies.jar \
	 -a localhost \
	 -b 7474 \
	 -c $NEO4J_USER \
	 -d $NEO4J_PASSWORD \
	 -e localhost \
	 -f gk_current \
	 -g root \
	 -h $MYSQL_ROOT_PASSWORD\
	 -o /diagrams | grep -v DEBUG > log
echo "Diagram generation is complete!"
ls -lht /diagrams | head
