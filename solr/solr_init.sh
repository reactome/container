#! /bin/bash

SOLR_CONFIG_DIR=$1
CORE_NAME=$2

set -x
solr start && solr create -c $CORE_NAME -p 8983
solr stop
cp -a $SOLR_CONFIG_DIR/* /opt/solr/server/solr/$CORE_NAME/conf/
solr start -f
set +x
