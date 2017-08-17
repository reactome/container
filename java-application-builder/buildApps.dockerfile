FROM maven:3.5-jdk-8
ENV PATHWAY_BROWSER_VERSION=v3.2.0
RUN mkdir -p /gitroot
WORKDIR /gitroot

# Build the PathwayBrowser application
RUN git clone https://github.com/reactome-pwp/browser.git
WORKDIR /gitroot/browser
RUN git checkout $PATHWAY_BROWSER_VERSION

# Need diagram-exporter for content-service and it's not in a repo so we will build it locally.
ENV DIAGRAM_EXPORTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/diagram-exporter.git
WORKDIR /gitroot/diagram-exporter
RUN git checkout $DIAGRAM_EXPORTER_VERSION

# Need SBMLExporter for content-service, building locally
ENV SBMLEXPORTER_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/SBMLExporter.git
WORKDIR /gitroot/SBMLExporter
RUN git checkout $SBMLEXPORTER_VERSION

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/content-service.git
WORKDIR /gitroot/content-service
RUN git checkout $CONTENT_SERVICE_VERSION

ENV DATA_CONTENT_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/data-content.git
WORKDIR /gitroot/data-content
RUN git checkout $DATA_CONTENT_VERSION

# search-core library is needed by data-content, but the *correct version*
# doesn't seem to be in any online repos.
# The repo:
# http://www.ebi.ac.uk/Tools/maven/repos/content/groups/ebi-repo/org/reactome/server/search/search-core/
# only has version 1.0.0.
ENV SEARCH_CORE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/search-core.git
WORKDIR /gitroot/search-core
RUN git checkout $SEARCH_CORE_VERSION


# Build the AnalysisService application
ENV ANALYSIS_SERVICE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/AnalysisTools.git
WORKDIR /gitroot/AnalysisTools/Service
RUN git checkout $ANALYSIS_SERVICE_VERSION

# To build the RESTfulAPI, we also need libsbgn and Pathway-Exchange.
# Let's start by building Pathway-Exchange
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/Pathway-Exchange.git

# then we'll need libsbgn and CuratorTool and they both requires ant
WORKDIR /gitroot/
RUN git clone https://github.com/sbgn/libsbgn.git
RUN git clone https://github.com/reactome/CuratorTool.git
WORKDIR /gitroot/libsbgn
RUN git checkout milestone2

WORKDIR /gitroot/
RUN git clone https://github.com/reactome/RESTfulAPI.git
WORKDIR /gitroot/RESTfulAPI
RUN git checkout master

# We need interactors-core to build interactors.db
WORKDIR /gitroot/
RUN git clone https://github.com/reactome-pwp/interactors-core.git
WORKDIR /gitroot/interactors-core
RUN git checkout master

# For building the Reactome solr index
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/search-indexer.git
WORKDIR /gitroot/search-indexer
RUN git checkout master

RUN apt-get update && apt-get install ant netcat -y && rm -rf /var/lib/apt/lists/*
