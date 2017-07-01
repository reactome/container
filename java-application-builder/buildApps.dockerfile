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

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=master
WORKDIR /gitroot/
RUN git clone https://github.com/reactome/content-service.git
WORKDIR /gitroot/content-service
RUN git checkout $CONTENT_SERVICE_VERSION

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

RUN apt-get update && apt-get install ant -y && rm -rf /var/lib/apt/lists/*

# Add ReactomeJar.xml to CuratorTool for building reactome.jar
COPY ReactomeJar.xml /gitroot/CuratorTool/