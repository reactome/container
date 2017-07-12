#! /bin/bash
# Build the container - this also builds the applications.
# docker build -t reactome-app-builder  -f buildApps.dockerfile .

# Running Analysis Service requires a working database,
# we are using the tomcat database: gk_current
# using defaults from mysql-for-tomcat container
docker run -itd \
	--name=mysql-for-webapps \
	--rm \
	--volume "$(dirname `pwd`)/mysql/tomcat_data/:/docker-entrypoint-initdb.d" \
	--env-file $(dirname `pwd`)/tomcat.env mysql
docker ps -a
exit
set -x
# Build the java applications
docker run -itd --name=java-webapp-builder --rm -v "$(pwd)/webapps:/webapps" \
	-v "$(pwd)/mounts/Pathway-Exchange-pom.xml:/gitroot/Pathway-Exchange/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Core-pom.xml:/gitroot/AnalysisTools/Core/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Service-pom.xml:/gitroot/AnalysisTools/Service/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Service-web.xml:/gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/web.xml" \
	-v "$(pwd)/mounts/ReactomeJar.xml:/gitroot/CuratorTool/ant/ReactomeJar.xml" \
	-v "$(pwd)/mounts/JavaBuildPackaging.xml:/gitroot/CuratorTool/ant/JavaBuildPackaging.xml" \
	-v "$(pwd)/mounts/CuratorToolBuild.xml:/gitroot/CuratorTool/ant/CuratorToolBuild.xml" \
	-v "$(pwd)/mounts/junit-4.12.jar:/gitroot/CuratorTool/lib/junit/junit-4.12.jar" \
	-v "$(pwd)/mounts/ant-javafx.jar:/gitroot/CuratorTool/lib/ant-javafx.jar" \
	-v "$(pwd)/mounts/RESTfulAPI-pom.xml:/gitroot/RESTfulAPI/pom.xml" \
	-v "$(pwd)/m2-cache:/root/.m2" \
	-v "$(pwd)/mounts/applicationContext.xml:/gitroot/RESTfulAPI/web/WEB-INF/applicationContext.xml" \
	-v "$(pwd)/mounts/applicationContext.xml:/gitroot/Pathway-Exchange/web/WEB-INF/applicationContext.xml" \
	reactome-app-builder \
	/bin/bash  -c "$(cat ./maven_builds.sh)"
set +x
