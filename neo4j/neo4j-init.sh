#!/bin/bash

# These cause problems with the latest docker-entrypoint.sh for neo4j.
# set -euo pipefail
# IFS=$'\n\t'

echo "Extension script started"
# do not run init script at each container start but only at the first start
if [ ! -f /tmp/neo4j-import-done.flag ]; then
    currentDir="$(pwd)"
    cd /var/lib/neo4j/data/databases/
    # new directory - contents of reactome.graphdb.tgz will be put in here
    # because the directory within reactome.graphdb.tgz is inconsistently named
    # (for example: reactome.graphdb.61 vs. reactome.graphdb.v62 - notice the
    # extra "v") and neo4j needs an EXACT directory name, so we will ensure
    # that the data will *always* be in "reactome.graphdb" - then we never
    # need to update dbms.active_database in neo4j.conf
    mkdir -p reactome.graphdb
    echo "Extracting reactome graphdb..."
    tar -C reactome.graphdb --strip-components=1  -xzf reactome.graphdb.tgz
    cd $currentDir
    touch /tmp/neo4j-import-done.flag
    chown -R neo4j:neo4j /var/lib/neo4j/data/databases/
    echo "Data-extraction is complete!"
    # clean up - the tgz is no longer needed.
    rm /var/lib/neo4j/data/databases/reactome.graphdb.tgz
else
    echo "The import has already been made."
fi
echo "The extension script is complete!"
