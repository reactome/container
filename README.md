# Reactome Container

## Table of Contents

- [Overview](#overview)
- [docker-compose](#docker-compose)
- [Stand-alone images](#Stand-alone-images)
- [Scripts](#scripts)
- [Jenkinsfiles](#jenkinsfiles)

## Overview

[Reactome](http://reactome.org/) is a free, open-source, curated and peer reviewed pathway database. It is an online bioinformatics database of human biology described in molecular terms. It is an on-line encyclopedia of core human pathways. [Reactome Wiki](http://wiki.reactome.org/index.php/Main_Page) provides more details about reactome.

There are two ways to use the contents of this repository. The first is to run a set of docker containers connected to each other with docker-compose. This is intended to replicate the Reactome production environment as closely as possible.

The second way is to build and run a set of stand-alone containers that only provide a single, independent service.

Be aware that building these images can be a resource-intensive process. You will want to ensure you have about 30 GB free to build the largest images. The final images are not that big, but docker will use up more disk space while its building. Some image-builds may also require &gt; 10 GB of RAM while building (Note: these numbers are estimates, based on observations made while building on one specific machine - resource usage might be different with different OS/hardware configurations).

### docker-compose

This option will create and run the following containers:

 - mysql-for-tomcat - This contains the Reactome's biological pathways, as a relational database.
 - mysql-for-joomla - THis contains Reactome's CMS (Joomla) content.
 - neo4j-db -  This contains the Reactome's biological pathways, as a graph database.
 - solr - This contains Reactome's solr index.
 - tomcat - This contains Tomcat, and all of the Reactome web applications.
 - joomla-sites - This contains the Reactome CMS (Reactome uses Joomla).

You can build these containers with a docker-compose command:
```bash
$ docker-compose build
```

You can run them with a run command (include the `-d` option if you want them to run in the background):
```bash
$ docker-compose up
```

**NOTE** At the time of writing (2021-07-08), the docker-compose setup is not actively used and some parts of it may be out-of-date.

### Stand-alone images

This option will help you build a series of stand-alone images that contain just enough to run a single Reactome service. The images are:

 - graphdb - This will create a docker image that contains Neo4j and the Reactome graph database.
 - stand-alone-content-service - This will create a docker image that contains the ContentService web application, and any supporting components (Neo4j, MySQL, Tomcat, Solr)
 - stand-alone-analysis-service - This will create a docker image that contains the AnalysisService web application, and any supporting components (Neo4j, Tomcat)
 - analysis-service-and-pwb - This will create a docker image that contains the PathwayBrowser and AnalysisService web applications, and any supporting components (Neo4j, MySQL, Tomcat, Solr, ContentService)

#### graphdb
In the [neo4j](./neo4j) directory, there are two dockerfiles: `neo4j_generated_from_mysql.dockerfile` & `neo4j_stand-alone.dockerfile`. `neo4j_generated_from_mysql.dockerfile` will build the Reactome graphdb docker image from the MySQL database using the [graph-importer](https://github.com/reactome/graph-importer). `neo4j_stand-alone.dockerfile` will build the docker image by downloading a pre-existing graph database from the Reactome [download page](https://reactome.org/download-data).

#### stand-alone-content-service
In the [stand-alone-content-service](./stand-alone-content-service) directory, there is a docker file named `content-service.dockerfile` that can be used to build a docker image that contains the ContentService, and all supporting components.

#### stand-alone-analysis-service
In the [stand-alone-analysis-service](./stand-alone-analysis-service) directory, there is a docker file named `analysis-service.dockerfile`. This will let you build a docker image that contains the AnalysisService and all supporting components.

#### analysis-service-and-pathwaybrowser
In the [pathway-browser](./pathway-browser) directory, there is a dockerfile named `pathway-browser.dockerfile`. This file will let you build a docker image that contains the PathwayBrowser & the Analysis Service and all supporting components.

### Scripts
There are a few convenience script to help build the stand-alone docker images.

 - build_all.sh
 - build_browser_and_analysisservice.sh
 - build_standalone_analysisservice.sh
 - build_standalone_content_service.sh

#### build_all.sh
This script builds all of the images needed to run the docker-compose setup. Be aware that the docker-compose setup is not actively used at the moment (2021-07-08) so this script might be out of date.

#### build_browser_and_analysisservice.sh
This script will build all of the images neede to build the final `stand-alone-analysis-service` image. It does not take any arguments. Be sure to update the value for `$RELEASE_VERSION` when you are running it for a new release.

#### build_standalone_analysisservice.sh
This script will build all of the images neede to build the final `stand-alone-analysis-service` image. It does not take any arguments. Be sure to update the value for `$RELEASE_VERSION` when you are running it for a new release.

#### build_standalone_contentservice.sh
This script will build all of the images neede to build the final `stand-alone-content-service` image. It does not take any arguments. Be sure to update the value for `$RELEASE_VERSION` when you are running it for a new release.

### Jenkinsfiles
There are a few Jenkinsfiles that can be used to build the docker images from Jenkins.

 - all-services.jenkinsfile - This file will build docker images for `stand-alone-analysis-service`, `stand-alone-analysis-service`, `stand-alone-analysis-service`, and `graphdb`.
 - analysis-service.jenkinsfile - This file will build docker images for `stand-alone-analysis-service`. NOTE: `all-services.jenkinsfile` is what's currently used in the Jenkins setup, so `stand-alone-analysis-service` might not be up to date.
 - content-service.jenkinsfile - This file will build docker images for `stand-alone-content-service`. NOTE: `all-services.jenkinsfile` is what's currently used in the Jenkins setup, so `stand-alone-content-service` might not be up to date.
