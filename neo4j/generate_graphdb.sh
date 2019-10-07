#! /bin/bash

# Start MySQL
# env
/usr/local/bin/docker-entrypoint.sh mysqld &

echo "Waiting for MySQL..."
bash /wait-for.sh localhost:3306 -t 90
cd /graph-importer/
# NOTE: NEO4J_USER and NEO4J_PASSWORD are set in the dockerfile.
# cat /etc/java-8-openjdk/accessibility.properties
echo -e "\n\n" > /etc/java-8-openjdk/accessibility.properties
echo "Generating the graph database..."
java -jar ./GraphImporter-jar-with-dependencies.jar \
	-h localhost \
	-s 3306 \
	-d current \
	-u root \
	-p $MYSQL_ROOT_PASSWORD \
	-n /graphdb \
	-i
echo "Contents of /graphdb: "
ls -hlt /graphdb
