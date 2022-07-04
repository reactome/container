# Stand-alone Reactome Content service

`content-service.dockerfile` can be used to build a stand-alone docker image that contains everything necessary to run Reactome's [ContentService](https://reactome.org/dev/content-service).

Because the ContentService relies on a number of other Reactome components, those will need to be built first.

The images that this image depends on are:
 - [graphdb](../neo4j)
 - [solr](../solr)
 - [diagrams](../diagram-generator)
 - [fireworks](../fireworks-generator)
 - [mysql](../mysql)

Once these images have been built locally, you can build the ContentService. This is as simple as:

```bash
docker build -t reactome/stand-alone-content-service:R71 -f content-service.dockerfile .
```

(Replace "R71" with a tag that is reflective of the version you are working with).

Run this as:
```bash
docker run --name reactome-content-service -p 8888:8080 reactome/stand-alone-content-service:R71
```
Access in you browser: http://localhost:8888/ContentService - this will let you see the various services.

It is more useful to interact with the ContentService programmatically. To use it from the command-line:
```bash
curl -X GET "http://localhost:8888/ContentService/data/complex/R-HSA-5674003/subunits?excludeStructures=false" -H "accept: application/json"
```
For exporter endpoints which return PDF files or images, be sure to use "--output FILE" with curl. For example:
```bash
curl --output R-HSA-177929_event.PDF -X GET "http://localhost:8888/ContentService/exporter/document/event/R-HSA-177929.pdf?level%20%5B0%20-%201%5D=1&diagramProfile=Modern&resource=total&analysisProfile=Standard" -H "accept: application/pdf"
```
