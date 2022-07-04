# Diagram generator

This dockerfile can be used to generate the diagram JSON files for Reactome, using the [diagram-converter](https://github.com/reactome-pwp/diagram-converter) application. The diagram JSON files will be placed in `/diagrams/`. This docker build depends on the [neo4j](../neo4j/) image.
