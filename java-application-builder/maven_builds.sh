#! /bin/bash
set -e
CuratorTool ()
{
  # Build Curator Tool
  cd /gitroot/libsbgn && ant \
  && cd /gitroot/CuratorTool/ant \
  && ant -buildfile ReactomeJar.xml \
  && ant -buildfile CuratorToolBuild.xml \
  && mvn install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION
}

PathwayExchange ()
{
  # CuratorTool
  # Build Pathway Exchange
  cd /gitroot/Pathway-Exchange \
  && mvn install:install-file -Dfile=/gitroot/libsbgn/dist/org.sbgn.jar -DartifactId=sbgn -DgroupId=org.sbgn -Dpackaging=jar -Dversion=milestone2 \
  && mvn install:install-file -Dfile=./lib/celldesigner/celldesigner.jar -DgroupId=celldesigner -DartifactId=celldesigner -Dversion=UNKNOWN_VERSION -Dpackaging=jar \
  && mvn install:install-file -Dfile=./lib/protege/arq.jar -DgroupId=com.hp.hpl.jena -DartifactId=arq -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && mvn install:install-file -Dfile=./lib/protege/protege.jar -Dpackaging=jar -DgroupId=edu.stanford.protege -DartifactId=protege -Dversion=UNKNOWN_VERSION \
  && mvn install:install-file -Dfile=./lib/protege/protege-owl.jar -Dversion=3.2 -DgroupId=edu.stanford.smi.protege -DartifactId=protege-owl -Dpackaging=jar \
  && mvn install:install-file -Dfile=lib/sbml/jsbml-0.8-rc1-with-dependencies.jar -DgroupId=org.sbml -DartifactId=jsbml -Dversion=0.8-rc1 -Dpackaging=jar \
  && mvn install:install-file -Dfile=./lib/sbml/libsbmlj.jar -DgroupId=org.sbml -DartifactId=libsbml -Dpackaging=jar -Dversion=0.8-rc1 \
  && pwd && mvn compile package install
}

RESTfulAPI ()
{
  # CuratorTool
  # Build RESTfulAPI
  cd /gitroot/RESTfulAPI \
  && mvn install:install-file -Dfile=/gitroot/CuratorTool/reactome.jar -DartifactId=Reactome -DgroupId=org.reactome -Dpackaging=jar -Dversion=UNKNOWN_VERSION \
  && ls /gitroot/RESTfulAPI/ -lht \
  && pwd && mvn package \
  && cp /gitroot/RESTfulAPI/target/ReactomeRESTfulAPI*.war /webapps/ReactomeRESTfulAPI.war
}

PathwayBrowser ()
{
  # Build Pathway Browser
  cd /gitroot/browser && mvn package \
  && cd /gitroot/diagram-exporter && mvn install \
  && cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war
}

ContentService ()
{
  # Build Content-service
  cd /gitroot/content-service
  mvn package -P ContentService-Local
  cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war
}

SearchCore()
{
  echo "building/installing search-core..."
  # build and install search-core
  cd /gitroot/search-core
  mvn package install -DskipTests=true
}

DataContent ()
{
  # Build data-content application
  # SearchCore
  cd /gitroot/data-content
  mvn package install -P DataContent-Local
  cp /gitroot/data-content/target/content*.war /webapps/content.war
}

AnalysisToolsCore ()
{
  # Analysis Tools requires core and service, building and installing core first
  cd /gitroot/AnalysisTools/Core && mvn package install
  echo "Following files were generated in Core/target"
  ls -a /gitroot/AnalysisTools/Core/target/
}

AnalysisBin ()
{
  # AnalysisToolsCore
  cd /gitroot/AnalysisTools/Core/target/
  echo "Building analysis.bin, required for running analysis service:"
  if ! [[ -f /downloads/interactors.db ]]; then
    InteractorsCore
  fi
  time java -jar tools-jar-with-dependencies.jar build \
        -h 172.25.3.3 \
        -d gk_current \
        -u root \
        -p root \
        -o ./analysis.bin \
        -g /downloads/interactors.db
  cp ./analysis.bin /downloads/
}

AnalysisToolsService ()
{
  # AnalysisToolsCore
  # Build AnalysisTools service using the "AnalysisService-Local" profile.
  cd /gitroot/AnalysisTools/Service && mvn package -P AnalysisService-Local
  cp /gitroot/AnalysisTools/Service/target/analysis-service*.war /webapps/
}

InteractorsCore ()
{
  echo "Creating interactors.db ..."
  cd /gitroot/interactors-core/ \
  && mvn package -DskipTests
  # if container has already been run once then the file would be present, we shall use that file
  if [[ -f /downloads/intact-micluster.txt ]]; then
    java -jar target/InteractorsParser-jar-with-dependencies.jar -g interactors.db -f /downloads/intact-micluster.txt
  else
    # else we need to download the intact-micluster.txt file (currently 315MB)
    java -jar target/InteractorsParser-jar-with-dependencies.jar -g interactors.db -d -t /downloads
  fi
  # Running tests
  mvn package install -Dinteractors.SQLite=interactors.db \
  && cp interactors.db /downloads/
  echo "Successfully created interactors.db"
}

# declare -A app_list
# # app_list+=( ["CuratorTool"]=ready )
# app_list+=( ["PathwayExchange"]=ready )
# app_list+=( ["RESTfulAPI"]=notready )
# app_list+=( ["PathwayBrowser"]=notready )
# app_list+=( ["ContentService"]=notready )
# # app_list+=( ["AnalysisToolsCore"]=notready )
# app_list+=( ["AnalysisToolsService"]=developing )
# # app_list+=( ["AnalysisBin"]=ready )
# # app_list+=( ["InteractorsCore"]=notready )

# Associative arrays are ordered according to hash, so using another simple array to preserve order
declare -A app_list;                                               declare -a orders
app_list+=( ["CuratorTool"]=$state_CuratorTool )                   orders+=("CuratorTool")
app_list+=( ["PathwayExchange"]=$state_PathwayExchange )           orders+=("PathwayExchange")
app_list+=( ["RESTfulAPI"]=$state_RESTfulAPI )                     orders+=("RESTfulAPI")
app_list+=( ["PathwayBrowser"]=$state_PathwayBrowser )             orders+=("PathwayBrowser")
app_list+=( ["SearchCore"]=$state_PathwayBrowser )                 orders+=("SearchCore")
app_list+=( ["DataContent"]=$state_DataContent )                   orders+=("DataContent")
app_list+=( ["ContentService"]=$state_ContentService )             orders+=("ContentService")
app_list+=( ["InteractorsCore"]=$state_InteractorsCore )           orders+=("InteractorsCore")
app_list+=( ["AnalysisToolsCore"]=$state_AnalysisToolsCore )       orders+=("AnalysisToolsCore")
app_list+=( ["AnalysisToolsService"]=$state_AnalysisToolsService ) orders+=("AnalysisToolsService")
app_list+=( ["AnalysisBin"]=$state_AnalysisBin )                   orders+=("AnalysisBin")
app_list+=( ["SearchIndexer"]=developing )                         orders+=("SearchIndexer")

for i in "${!orders[@]}";
do
  echo -e "\n\n"
  echo "############################################################"
  echo "# Application: ${orders[$i]}"
  echo "# State:     : ${app_list[${orders[$i]}]}"
  echo "############################################################"
  if [[ ${app_list[${orders[$i]}]} == "ready" ]];
  then
    echo "Application ready! Skippinig ${orders[$i]}"
  elif [[ ${app_list[${orders[$i]}]} == "develop" ]];
  then
    echo "Developing ${orders[$i]}:"
    ${orders[$i]}
  else
    echo "Unknown application state ${orders[$i]}"
  fi
done
set +e
