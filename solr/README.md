# Solr index builder for Reactome

The dockerfile in this directory can be used to create a Solr index for Reactome.

 - index-builder.dockerfile - This file will create a docker image that, as a part of its build process, will build the Solr index for Reactome. To do this, the [search-indexer](https://github.com/reactome/search-indexer.git) will be run on the Reactome [graph database](../neo4j/), which must already exist in a docker image. At the end of this process, the docker image should contain Solr, and the complete Solr index for Reactome.

 - solr-security.json - this contains the username and password for solr.

 - build_solr_index.sh - This is the script that will actually run the search indexer.
