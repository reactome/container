#! /bin/bash
echo "starting neo4j..."
cd /neo4j/neo4j-community-3.4.10/bin/

echo -e "dbms.active_database=graph.db\ndbms.security.auth_enabled=false\ndbms.allow_format_migration=true\n" >>  /neo4j/neo4j-community-3.4.10/conf/neo4j.conf

./neo4j start &
end="$((SECONDS+60))"
echo "waiting for neo4j to start up..."
while true; do
	echo "waiting..."
    [[ "200" = "$(curl --silent --write-out %{http_code} --output /dev/null http://localhost:7474)" ]] && break
    [[ "${SECONDS}" -ge "${end}" ]] && exit 1
    sleep 1
done
echo "Starting tomcat..."
# Now that Neo4j has been started, we can run tomcat
cd /usr/local/tomcat
catalina.sh run
