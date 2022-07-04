# Analysis-core dockerfiles

The AnalysisService requires an intermediate file. The dockerfile here can be used to generate it.

 - analysis-core.dockerfile - This file will build the Analysis-Core (https://github.com/reactome/analysis-core) file for the AnalysisService. This process requires that the Reactome graph database already exist. See [neo4j](../neo4j/README.md) for more information about setting up the Reactom graph database image.

The resulting output file is stored in the image as `/output/analysis.bin`. To make use of this image, you can use it in a multistage build:

```dockerfile
FROM ubuntu:18.04
...
FROM reactome/analysis-core as analysiscore
COPY --from=analysiscore /output/analysis.bin /analysis.bin
...
```
