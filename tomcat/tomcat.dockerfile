# "Builder" layer
FROM maven:3.5-jdk-8 AS builder
ENV PATHWAY_BROWSER_VERSION=v3.5.0
RUN mkdir -p /gitroot
WORKDIR /gitroot

# Build the PathwayBrowser application
RUN git clone https://github.com/reactome-pwp/browser.git \
  && cd /gitroot/browser \
  && git checkout $PATHWAY_BROWSER_VERSION

# Need diagram-exporter for content-service and it's not in a repo so we will build it locally.
ENV DIAGRAM_EXPORTER_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome-pwp/diagram-exporter.git \
  && cd /gitroot/diagram-exporter \
  && git checkout $DIAGRAM_EXPORTER_VERSION

# Need SBMLExporter for content-service, building locally
ENV SBMLEXPORTER_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/SBMLExporter.git \
  && cd /gitroot/SBMLExporter \
  && git checkout $SBMLEXPORTER_VERSION

# Build the ContentService application
ENV CONTENT_SERVICE_VERSION=v1.0.0
RUN cd /gitroot/ && git clone https://github.com/reactome/content-service.git \
  && cd /gitroot/content-service \
  && git checkout $CONTENT_SERVICE_VERSION

ENV DATA_CONTENT_VERSION=v1.0.0
RUN cd /gitroot/ && git clone https://github.com/reactome/data-content.git \
  && cd /gitroot/data-content \
  && git checkout $DATA_CONTENT_VERSION

# search-core library is needed by data-content, but the *correct version*
# doesn't seem to be in any online repos.
# The repo:
# http://www.ebi.ac.uk/Tools/maven/repos/content/groups/ebi-repo/org/reactome/server/search/search-core/
# only has version 1.0.0.
ENV SEARCH_CORE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/search-core.git \
  && cd /gitroot/search-core \
  && git checkout $SEARCH_CORE_VERSION

# Build the AnalysisService application
ENV ANALYSIS_SERVICE_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/AnalysisTools.git \
  && cd /gitroot/AnalysisTools/Service \
  && git checkout $ANALYSIS_SERVICE_VERSION

# To build the RESTfulAPI, we also need libsbgn and Pathway-Exchange.
# Let's start by building Pathway-Exchange
RUN cd /gitroot/ && git clone https://github.com/reactome/Pathway-Exchange.git

# then we'll need libsbgn and CuratorTool and they both requires ant
RUN cd /gitroot/ && git clone https://github.com/sbgn/libsbgn.git
RUN cd /gitroot/ && git clone https://github.com/reactome/CuratorTool.git
WORKDIR /gitroot/libsbgn && git checkout milestone2

RUN cd /gitroot/ && git clone https://github.com/reactome/RESTfulAPI.git \
 && cd /gitroot/RESTfulAPI \
 && git checkout master

# We need interactors-core to build interactors.db
RUN cd /gitroot/ && git clone https://github.com/reactome-pwp/interactors-core.git \
  && cd /gitroot/interactors-core \
  && git checkout master

# Install ant (needed for CuratorTool and libsbgn)
RUN apt-get update && apt-get install ant -y && rm -rf /var/lib/apt/lists/*

# COPY ./maven_builds.sh /maven_builds.sh
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
COPY ./java-build-mounts/CuratorToolBuild.xml /gitroot/CuratorTool/ant/CuratorToolBuild.xml
COPY ./java-build-mounts/ReactomeJar.xml /gitroot/CuratorTool/ant/ReactomeJar.xml
COPY ./java-build-mounts/JavaBuildPackaging.xml /gitroot/CuratorTool/ant/JavaBuildPackaging.xml
COPY ./java-build-mounts/junit-4.12.jar /gitroot/CuratorTool/lib/junit/junit-4.12.jar
COPY ./java-build-mounts/ant-javafx.jar /gitroot/CuratorTool/lib/ant-javafx.jar
COPY ./java-build-mounts/Pathway-Exchange-pom.xml /gitroot/Pathway-Exchange/pom.xml
COPY ./java-build-mounts/AnalysisService_mvc-dispatcher-servlet.xml /gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/mvc-dispatcher-servlet.xm
COPY ./java-build-mounts/AnalysisTools-Service-web.xml /gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/web.xml
COPY ./java-build-mounts/RESTfulAPI-pom.xml /gitroot/RESTfulAPI/pom.xml
COPY ./java-build-mounts/applicationContext.xml /gitroot/RESTfulAPI/web/WEB-INF/applicationContext.xml
COPY ./java-build-mounts/applicationContext.xml /gitroot/Pathway-Exchange/web/WEB-INF/applicationContext.xml
RUN mkdir /webapps
ENV MVN_CMD "mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/.m2nrepo/repository"
#RUN bash /maven_builds.sh
RUN cd /gitroot/libsbgn && ant \
	&& cd /gitroot/CuratorTool/ant \
	&& ant -buildfile ReactomeJar.xml \
	&& ant -buildfile CuratorToolBuild.xml \
	&& $MVN_CMD install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION
RUN cd /gitroot/Pathway-Exchange \
  && $MVN_CMD install:install-file -Dfile=/gitroot/libsbgn/dist/org.sbgn.jar -DartifactId=sbgn -DgroupId=org.sbgn -Dpackaging=jar -Dversion=milestone2 \
  && $MVN_CMD install:install-file -Dfile=./lib/celldesigner/celldesigner.jar -DgroupId=celldesigner -DartifactId=celldesigner -Dversion=UNKNOWN_VERSION -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/arq.jar -DgroupId=com.hp.hpl.jena -DartifactId=arq -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/protege.jar -Dpackaging=jar -DgroupId=edu.stanford.protege -DartifactId=protege -Dversion=UNKNOWN_VERSION \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/protege-owl.jar -Dversion=3.2 -DgroupId=edu.stanford.smi.protege -DartifactId=protege-owl -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=lib/sbml/jsbml-0.8-rc1-with-dependencies.jar -DgroupId=org.sbml -DartifactId=jsbml -Dversion=0.8-rc1 -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=./lib/sbml/libsbmlj.jar -DgroupId=org.sbml -DartifactId=libsbml -Dpackaging=jar -Dversion=0.8-rc1 \
  && pwd && $MVN_CMD compile package install
RUN cd /gitroot/RESTfulAPI \
  && $MVN_CMD install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && ls /gitroot/RESTfulAPI/ -lht \
  && pwd && $MVN_CMD package \
  && cp /gitroot/RESTfulAPI/target/ReactomeRESTfulAPI*.war /webapps/ReactomeRESTfulAPI.war

# RUN cd /gitroot/diagram-exporter && $MVN_CMD install -DskipTests

RUN cd /gitroot/browser && $MVN_CMD package \
  && cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war

RUN cd /gitroot/SBMLExporter && $MVN_CMD package install -DskipTests

RUN cd /gitroot/content-service \
  && $MVN_CMD package -P ContentService-Local \
  && cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war

# COPY ./java-build-mounts/data-content-pom.xml /gitroot/data-content/pom.xml
# Rename customTag.tld to implicit.tld
# For more information see: https://stackoverflow.com/questions/38593625/java-error-message-invalid-tld-file-see-jsp-2-2-specification-section-7-3-1-fo/39264879#39264879
RUN cd /gitroot/data-content \
  && mv src/main/webapp/WEB-INF/tags/customTag.tld src/main/webapp/WEB-INF/tags/implicit.tld \
  && { for f in $(grep -RIH customTag.tld . | cut -d ':' -f 1) ; do echo "fixing customTag.tld name in  $f" ; sed -i -e 's/customTag\.tld/implicit.tld/g' $f ; done ; } \
  && echo "Files still referencing customTag.tld" \
  && grep -RH customTag.tld . | cut -d ':' -f 1 \
  && $MVN_CMD package install -P DataContent-Local \
  && cp /gitroot/data-content/target/content*.war /webapps/content.war

RUN cd /gitroot/AnalysisTools/Core && $MVN_CMD package install \
  && echo "Following files were generated in Core/target" \
  && ls -a /gitroot/AnalysisTools/Core/target/
# COPY ./java-build-mounts/AnalysisTools-Service-pom.xml /gitroot/AnalysisService/Service/pom.xml
RUN   cd /gitroot/AnalysisTools/Service && $MVN_CMD  package -DskipTests -P AnalysisService-Local \
  && cp /gitroot/AnalysisTools/Service/target/analysis-service*.war /webapps/

# Ok, now re-base the image as Tomcat
FROM tomcat:8-jre8
# Copy the web applications created in the builder stage.
COPY --from=builder /webapps/ /usr/local/tomcat/webapps/
RUN ls -lht /usr/local/tomcat/webapps

# Install netcat so this container can check if other containers are running.
RUN apt-get update && apt-get install -y netcat \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /usr/local/interactors/tuple
