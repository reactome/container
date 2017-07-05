#! /bin/bash
# Build the container - this also builds the applications.
docker build -t reactome-app-builder  -f buildApps.dockerfile .
# Copy the webapps to the shared directory ./webapps
set -x
docker run -it --name=java-webapp-builder --rm -v "$(pwd)/webapps:/webapps" \
	-v "$(pwd)/Pathway-Exchange-pom.xml:/gitroot/Pathway-Exchange/pom.xml" \
	-v "$(pwd)/ReactomeJar.xml:/gitroot/CuratorTool/ant/ReactomeJar.xml" \
	-v "$(pwd)/JavaBuildPackaging.xml:/gitroot/CuratorTool/ant/JavaBuildPackaging.xml" \
	-v "$(pwd)/CuratorToolBuild.xml:/gitroot/CuratorTool/ant/CuratorToolBuild.xml" \
	-v "$(pwd)/junit-4.12.jar:/gitroot/CuratorTool/lib/junit/junit-4.12.jar" \
	-v "$(pwd)/ant-javafx.jar:/gitroot/CuratorTool/lib/ant-javafx.jar" \
	-v "$(pwd)/RESTfulAPI-pom.xml:/gitroot/RESTfulAPI/pom.xml" \
	-v "$(pwd)/m2-cache:/root/.m2" \
	-v "$(pwd)/applicationContext.xml:/gitroot/RESTfulAPI/web/WEB-INF/applicationContext.xml" \
	-v "$(pwd)/applicationContext.xml:/gitroot/Pathway-Exchange/web/WEB-INF/applicationContext.xml" \
	reactome-app-builder \
	/bin/bash  -c "$(cat ./maven_builds.sh)"
set +x
