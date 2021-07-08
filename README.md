

:warning: _**ATTENTION**_ :warning:

This project is currently a :construction: "work-in-progress" :construction:. The most current code is currently on the [feature/Joomla](https://github.com/reactome/container/tree/feature/Joomla) branch, though please be aware that since there is active development on that branch, the code may change unexpectedly.

# Reactome Container

## Table of Contents

- [Overview](#overview)
- [Details](#details)
- [Setup](#set-up)
- [Bulding the docker images](#Bulding-the-docker-images)
- [How to use](#how-to-use)
- [Configuration](#configuration)

## Overview

[Reactome](http://reactome.org/) is a free, open-source, curated and peer reviewed pathway database. It is an online bioinformatics database of human biology described in molecular terms. It is an on-line encyclopedia of core human pathways. [Reactome Wiki](http://wiki.reactome.org/index.php/Main_Page) provides more details about reactome.

There are two ways to use the contents of this repository. The first is to run a set of docker containers connected to each other with docker-compose. This is intended to replicate the Reactome production environment as closely as possible.

The second way is to build and run a set of stand-alone containers that only provide a single, independent service.

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
