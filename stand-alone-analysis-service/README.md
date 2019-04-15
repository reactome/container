# :construction: Stand-alone Reactome Analysis service :construction:

This document explains how to build and run Reactome's AnalysisService as a stand-alone service that runs in its own docker container.

1. Clone this repository and navigate to this Directory

2. Build the docker image:
```bash
docker build -t reactome_analysis_service -f analysis-service.dockerfile .
```

3. Download the Reactome graph database and extract it to the stand-alone-analysis-service directory:
```bash
wget https://reactome.org/download/current/reactome.graphdb.tgz
tar -xzf reactome.graphdb.tgz
```

4. Run the docker container which you just built. This can be done with the command:
```bash
docker run --name analysis-service --rm -v $(pwd)/reactome.graphdb.v66:/neo4j/neo4j-community-3.4.10/data/databases/graph.db -p 8888:8080 reactome_analysis_service
```
:warning: **NOTE:** You may need to change the mount for the graph database, depending on the version of the file you download (the "_v66_" in the mount: `reactome.graphdb.v66:/neo4j/neo4j-community-3.4.10/data/databases/graph.db`).
