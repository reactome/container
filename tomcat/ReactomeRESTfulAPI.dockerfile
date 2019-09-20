FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"
RUN apt-get update && apt-get install -y ant
# To build the RESTfulAPI, we also need libsbgn and Pathway-Exchange.
# Let's start by building Pathway-Exchange
RUN cd /gitroot/ && git clone https://github.com/reactome/Pathway-Exchange.git

# then we'll need libsbgn (version: "milestone2") and CuratorTool, and *they* both requires ant
RUN cd /gitroot/ && git clone https://github.com/sbgn/libsbgn.git \
  && cd /gitroot/libsbgn && git checkout milestone2
RUN cd /gitroot/ && git clone https://github.com/reactome/CuratorTool.git
WORKDIR /gitroot/libsbgn

# Build projects from the CuratorTool - need to build reactome.jar before building RestfulAPI
COPY ./java-build-mounts/CuratorToolBuild.xml /gitroot/CuratorTool/ant/CuratorToolBuild.xml
COPY ./java-build-mounts/ReactomeJar.xml /gitroot/CuratorTool/ant/ReactomeJar.xml
COPY ./java-build-mounts/JavaBuildPackaging.xml /gitroot/CuratorTool/ant/JavaBuildPackaging.xml
COPY ./java-build-mounts/junit-4.12.jar /gitroot/CuratorTool/lib/junit/junit-4.12.jar
COPY ./java-build-mounts/ant-javafx.jar /gitroot/CuratorTool/lib/ant-javafx.jar
COPY ./java-build-mounts/ols-client-1.18.jar /gitroot/CuratorTool/lib/ols-client-1.18.jar
RUN ant
WORKDIR /gitroot/CuratorTool/ant
RUN ant -buildfile ReactomeJar.xml

RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"
RUN cd /gitroot/CuratorTool/ant && $MVN_CMD install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION

# Build Pathway-Exchange
COPY ./java-build-mounts/Pathway-Exchange-pom.xml /gitroot/Pathway-Exchange/pom.xml
COPY ./java-build-mounts/applicationContext.xml /gitroot/Pathway-Exchange/web/WEB-INF/applicationContext.xml
# Install libs for PathwayExchange, then build PathwayExchange
RUN cd /gitroot/Pathway-Exchange \
  && $MVN_CMD install:install-file -Dfile=/gitroot/libsbgn/dist/org.sbgn.jar -DartifactId=sbgn -DgroupId=org.sbgn -Dpackaging=jar -Dversion=milestone2 \
  && $MVN_CMD install:install-file -Dfile=./lib/celldesigner/celldesigner.jar -DgroupId=celldesigner -DartifactId=celldesigner -Dversion=UNKNOWN_VERSION -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/arq.jar -DgroupId=com.hp.hpl.jena -DartifactId=arq -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/protege.jar -Dpackaging=jar -DgroupId=edu.stanford.protege -DartifactId=protege -Dversion=UNKNOWN_VERSION \
  && $MVN_CMD install:install-file -Dfile=./lib/protege/protege-owl.jar -Dversion=3.2 -DgroupId=edu.stanford.smi.protege -DartifactId=protege-owl -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=lib/sbml/jsbml-0.8-rc1-with-dependencies.jar -DgroupId=org.sbml -DartifactId=jsbml -Dversion=0.8-rc1 -Dpackaging=jar \
  && $MVN_CMD install:install-file -Dfile=./lib/sbml/libsbmlj.jar -DgroupId=org.sbml -DartifactId=libsbml -Dpackaging=jar -Dversion=0.8-rc1 \
  && pwd && $MVN_CMD compile package install && du -hscx /mvn/alt-m2/

# Build RESTfulAPI - the one I copied as a WAR doesn't seem to work right.
RUN cd /gitroot/ && git clone https://github.com/reactome/RESTfulAPI.git \
  && cd /gitroot/RESTfulAPI \
  && git checkout master
COPY ./java-build-mounts/RESTfulAPI-pom.xml /gitroot/RESTfulAPI/pom.xml
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN cd /gitroot/RESTfulAPI \
  && $MVN_CMD install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && ls /gitroot/RESTfulAPI/ -lht \
  && pwd && $MVN_CMD package \
  && cp /gitroot/RESTfulAPI/target/ReactomeRESTfulAPI*.war /webapps/ReactomeRESTfulAPI.war && du -hscx /mvn/alt-m2/

FROM alpine:3.8
COPY --from=builder /webapps/ReactomeRESTfulAPI.war /webapps/ReactomeRESTfulAPI.war
