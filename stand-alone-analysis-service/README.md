# Stand-alone Reactome Analysis service

`analysis-service.dockerfile` will let you build and run a stand-alone version of Reactome's [AnalysisService](https://reactome.org/dev/analysis-service) inside a docker image.

AnalysisService relies on a number of other components so those docker iamges will need to be built first:
 - [analysis-core](../analysis-core)
 - [graphdb](../neo4j)
 - [fireworks](../fireworks-generator)
 - [diagrams](../diagram-generator)

Once those images have been successfuly built, you can build the AnalysisService image like this:

```bash
docker build -t reactome/stand-alone-analysis-service:R71 -f analysis-service.dockerfile .
```
(Replace "R71" with a tag that is reflective of the version you are working with).

Run this as:
```bash
docker run --name reactome-analysis-service -p 8888:8080 reactome/stand-alone-analysis-service:R71
```

Access in you browser: http://localhost:8888/AnalysisService - this will let you see the various services.

It is more useful to interact with this service programmatically. To use it from the command-line:
```bash
curl -X GET "http://localhost:8888/AnalysisService/database/name" -H "accept: text/plain"
```
