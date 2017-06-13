#! /bin/bash
# Build the container - this also builds the applications.
docker build -t reactome-app-builder  -f buildApps.dockerfile .
# Copy the webapps to the shared directory ./webapps
docker run -it --rm -v $(pwd)/webapps:/webapps reactome-app-builder \
	/bin/bash  -c "cp /gitroot/browser/target/PathwayBrowser*.war /webapps/PathwayBrowser.war && \
				cp /gitroot/content-service/target/ContentService*.war /webapps/ContentService.war && \
				cp /gitroot/AnalysisTools/Service/target/analysis-service*.war /webapps/analysis-service.war"
