#! /bin/bash

cd /gitroot/libsbgn && ant && \
cd /gitroot/CuratorTool/ant && \
ant -buildfile ReactomeJar.xml && \
ant -buildfile CuratorToolBuild.xml && \
cd /gitroot/RESTfulAPI/ \
&& mvn install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
&& cd /gitroot/Pathway-Exchange \
&& mvn install:install-file -Dfile=/gitroot/libsbgn/dist/org.sbgn.jar -DartifactId=sbgn -DgroupId=org.sbgn -Dpackaging=jar -Dversion=milestone2 \
&& mvn install:install-file -Dfile=./lib/celldesigner/celldesigner.jar -DgroupId=celldesigner -DartifactId=celldesigner -Dversion=UNKNOWN_VERSION -Dpackaging=jar \
&& mvn install:install-file -Dfile=./lib/protege/arq.jar -DgroupId=com.hp.hpl.jena -DartifactId=arq -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
&& mvn install:install-file -Dfile=./lib/protege/protege.jar -Dpackaging=jar -DgroupId=edu.stanford.protege -DartifactId=protege -Dversion=UNKNOWN_VERSION \
&& mvn install:install-file -Dfile=./lib/protege/protege-owl.jar -Dversion=3.2 -DgroupId=edu.stanford.smi.protege -DartifactId=protege-owl -Dpackaging=jar \
&& mvn install:install-file -Dfile=lib/sbml/jsbml-0.8-rc1-with-dependencies.jar -DgroupId=org.sbml -DartifactId=jsbml -Dversion=0.8-rc1 -Dpackaging=jar \
&& mvn install:install-file -Dfile=./lib/sbml/libsbmlj.jar -DgroupId=org.sbml -DartifactId=libsbml -Dpackaging=jar -Dversion=0.8-rc1 \
&& pwd && mvn compile package install \
&& cd /gitroot/RESTfulAPI/ -lht \
&& pwd && mvn package \
&& cd /gitroot/browser && mvn package && \
cd /gitroot/diagram-exporter && mvn install && \
# cd /gitroot/content-service && mvn package && \
# cd /gitroot/AnalysisTools/Core && mvn package install && \
# cd /gitroot/AnalysisTools/Service && mvn package && \
cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war && \
# cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war && \
# cp /gitroot/AnalysisTools/Service/target/analysis-service*.war /webapps/analysis-service.war && \
cp /gitroot/RESTfulAPI/target/ReactomeRESTfulAPI*.war /webapps/ReactomeRESTfulAPI.war
