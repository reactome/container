#! /bin/bash

docker build -t reactome-app-builder  -f buildApps.dockerfile .

docker run -it --rm -v $(pwd)/docker-maven-cache:/root/.m2 -v $(pwd)/webapps:/webapps reactome-app-builder \
	/bin/bash  -c "cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war && \
				cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war"
