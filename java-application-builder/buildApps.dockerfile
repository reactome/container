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

# then we'll need libsbgn and that requires ant
WORKDIR /gitroot/
RUN git clone https://github.com/sbgn/libsbgn.git
WORKDIR /gitroot/libsbgn
RUN git checkout milestone2

WORKDIR /gitroot/
RUN git clone https://github.com/reactome/RESTfulAPI.git
WORKDIR /gitroot/RESTfulAPI
RUN git checkout master

RUN apt-get update && apt-get install ant -y
#
# # really, these build commands should not be a part of the *image* build
# # but commands that are executed with a running *container* from this image.
# RUN cd /gitroot/browser && mvn package && \
# 	cd /gitroot/diagram-exporter && mvn install && \
# 	cd /gitroot/content-service && mvn package && \
# 	cd /gitroot/AnalysisTools/Core && mvn package install && \
# 	cd /gitroot/AnalysisTools/Service && mvn package
