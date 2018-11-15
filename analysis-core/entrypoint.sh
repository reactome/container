#! /bin/bash
echo "starting neo4j..."
neo4j start &
end="$((SECONDS+60))"
echo "waiting for neo4j to start up..."
while true; do
	echo "waiting..."
    [[ "200" = "$(curl --silent --write-out %{http_code} --output /dev/null http://localhost:7474)" ]] && break
    [[ "${SECONDS}" -ge "${end}" ]] && exit 1
    sleep 1
done

time java -jar /applications/analysis-core-jar-with-dependencies.jar -h localhost -p 7474 -u neo4j -k neo4j -o /output/analysis.bin -t -v
