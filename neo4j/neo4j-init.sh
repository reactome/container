#! /bin/bash

# These cause problems with the latest docker-entrypoint.sh for neo4j.
# set -euo pipefail
# IFS=$'\n\t'

echo "Extension script started"
ls -lht /data
ls -lht /data/databases/
# do not run init script at each container start but only at the first start
# TODO: Check for the existence of /var/lib/neo4j/data/databases/reactome.graphdb.tgz
# or that the directory  /data/databases/reactome.graphdb/ does not exist (or if it does, it's empty).
# This flag thing is causing problems.
# if [ ! -e /data/neo4j-import-done.flag ]; then
if [ -e /var/lib/neo4j/data/databases/reactome.graphdb.tgz ] ; then
    # currentDir="$(pwd)"
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
    # cd $currentDir
    # touch /data/neo4j-import-done.flag
    ls -lht /data
    chown -R neo4j:neo4j /var/lib/neo4j/data/databases/
    echo "Data-extraction is complete!"
    # clean up - the tgz is no longer needed.
    rm /var/lib/neo4j/data/databases/reactome.graphdb.tgz
    du -hscx /var/lib/neo4j/data/databases/reactome.graphdb
else
    echo "The graphdb file reactome.graphdb.tgz was not present as \"/var/lib/neo4j/data/databases/reactome.graphdb.tgz\" - perhaps it has already been imported and the tgz has been removed."
fi
echo "The extension script is complete!"
