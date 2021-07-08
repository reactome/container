# Neo4j docker container for Reactome

The dockerfiles in this directory can be used to build docker images containing Reactome data in a ready-to-use docker image.

 - neo4j_stand-alone.dockerfile - this is used to build a new docker image that contains the Reactome graph database. In order to use this, you must first download the Reactome graph database (you can find it on the Reactome downloads page: https://reactome.org/download-data) and place it in the same directory as this dockerfile. Be sure to rename the file with the approprite Release number. For example, if you are working with the Release 67 graph database file, name it "reactome-R67.graphdb.tgz". This is important because the dockerfile requires a file with the name `reactome-${RELEASE_VERSION}.graphdb.tgz`. Building the graph database with this dockerfile is probably more appropriate for users who ONLY want the graph database.

 Build this image like this:

```bash
docker build -t reactome/grapdb:R999 \
    --build-arg NEO4J_USER=neo4j \
    --build-arg NEO4J_PASSWORD=xxxx \
    --build-arg RELEASE_VERSION=999 \
    -f ./neo4j_stand-alone.dockerfile .
```
The image can be run like this:
```bash
docker run --rm -p 7474:7474 -p 7687:7687 --name reactome-graphdb reactome/graphdb:R999
```
 - neo4j-ini.sh - this is used to extract and prepare the graph database file for neo4j.

 - neo4j_generated_from_mysql.dockerfile - this is used to build a new docker image that contains the Reactome graph database. This dockerfile will build the graph database from the data in the Reactome MySQL database. See [mysql](../mysql/README.md) for more information about the MySQL database. This dockerfile is used by others which can be used to run the entire Reactome system in docker containers.
 - generate_graphdb.sh - this is used to generate the graph database from the relational database using the [graph-importer](https://github.com/reactome/graph-importer).
