#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "Initialization script started"
# do not run init script at each container start but only at the first start
if [ ! -f /tmp/neo4j-import-done.flag ]; then
    currentDir="$(pwd)"
    cd /var/lib/neo4j/data/databases/
    tar -xvzf /var/lib/neo4j/data/databases/reactome.graphdb.tgz
    cd $currentDir
    touch /tmp/neo4j-import-done.flag
else
    echo "The import has already been made."
fi
