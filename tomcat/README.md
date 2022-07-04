# Tomcat image for Reactome

The files in this directory are used to build the tomcat image for Reactome.

 - AnalysisService.dockerfile - This dockerfile will build the AnalysisService WAR file.
 - ContentService.dockerfile - This dockerfile will build the ContentService WAR file.
 - data-content.dockerfile - This dockerfile will build the data-content WAR file.
 - DiagramJs.dockerfile - This dockerfile will build the DiagramJs WAR file.
 - FireworksJs.dockerfile - This dockerfile will build the FireworksJs WAR file.
 - PathwayBrowser.dockerfile - This dockerfile will build the PathwayBrowser WAR file.
 - ReactomeRESTfulAPI.dockerfile - This dockerfile will build the ReactomeRESTfulAPI WAR file.
 - tomcat.dockerfile - This dockerfile is a multi-stage build that will copy web applications and other components from other docker images and include them into this one. Images that this depends on are the images built by the dockerfiles liste above (AnalysisService.dockerfile, ContentService.dockerfile, ...) as well as images built by [diagram-generator](../diagram-generator), [fireworks-generator](../fireworks-generator), and [AnalysisCore](../analysis-core).

 - java-build-mounts - The files in this directory containe configuration for building the Java applications.

 - properties - The files in this directory contain properties files that will be used by the Java applications at run-time.
