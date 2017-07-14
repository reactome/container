#! /bin/bash
# Build the container - this also builds the applications.
docker build -t reactome-app-builder -f buildApps.dockerfile .

echo "Running Analysis Service requires a working database"
# we are using the tomcat database: gk_current
# using defaults from mysql-for-tomcat container
docker network create -d bridge --subnet 172.25.0.0/16 isolated_nw
docker run -itd --rm \
	--network=isolated_nw \
	--ip=172.25.3.3 \
	--name=mysql-for-webapps \
	--volume "$(dirname `pwd`)/mysql/tomcat_data/:/docker-entrypoint-initdb.d" \
	--env-file $(dirname `pwd`)/tomcat.env mysql

# Build the java applications
docker run -it --name=java-webapp-builder --rm -v "$(pwd)/webapps:/webapps" \
    --network=isolated_nw \
	-v "$(pwd)/mounts/Pathway-Exchange-pom.xml:/gitroot/Pathway-Exchange/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Core-pom.xml:/gitroot/AnalysisTools/Core/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Service-pom.xml:/gitroot/AnalysisTools/Service/pom.xml" \
	-v "$(pwd)/mounts/AnalysisTools-Service-web.xml:/gitroot/AnalysisTools/Service/src/main/webapp/WEB-INF/web.xml" \
	-v "$(pwd)/mounts/interactors.db:/gitroot/AnalysisTools/interactors.db" \
	-v "$(pwd)/mounts/ReactomeJar.xml:/gitroot/CuratorTool/ant/ReactomeJar.xml" \
	-v "$(pwd)/mounts/JavaBuildPackaging.xml:/gitroot/CuratorTool/ant/JavaBuildPackaging.xml" \
	-v "$(pwd)/mounts/CuratorToolBuild.xml:/gitroot/CuratorTool/ant/CuratorToolBuild.xml" \
	-v "$(pwd)/mounts/junit-4.12.jar:/gitroot/CuratorTool/lib/junit/junit-4.12.jar" \
	-v "$(pwd)/mounts/ant-javafx.jar:/gitroot/CuratorTool/lib/ant-javafx.jar" \
	-v "$(pwd)/mounts/RESTfulAPI-pom.xml:/gitroot/RESTfulAPI/pom.xml" \
	-v "$(pwd)/m2-cache:/root/.m2" \
	-v "$(pwd)/mounts/applicationContext.xml:/gitroot/RESTfulAPI/web/WEB-INF/applicationContext.xml" \
	-v "$(pwd)/mounts/applicationContext.xml:/gitroot/Pathway-Exchange/web/WEB-INF/applicationContext.xml" \
	-v "$(pwd)/maven_builds.sh:/maven_builds.sh" \
	--entrypoint="/maven_builds.sh" \
	reactome-app-builder
echo "java-webapp-builder exited, stopping mysql-for-webapps..."
docker stop mysql-for-webapps