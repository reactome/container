FROM maven:3.6.3-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --no-transfer-progress --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV EXPERIMENT_DIGESTER_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/experiment-digester.git \
  && cd /gitroot/experiment-digester \
  && git checkout $EXPERIMENT_DIGESTER_VERSION

RUN cd /gitroot/experiment-digester \
  && $MVN_CMD -P Experiment-Digester-Local package -DskipTests \
  && ls -lht /gitroot/experiment-digester/target

# Generate the experiments.bin file
RUN cd /gitroot/experiment-digester && \
  java -jar target/digester-importer-jar-with-dependencies.jar \
    -o /experiments.bin \
    -e https://www.ebi.ac.uk/gxa/experiments-content/E-PROT-3/resources/ExperimentDownloadSupplier.Proteomics/tsv && \
  ls -lht /experiments.bin

RUN cp /gitroot/experiment-digester/target/ExperimentDigester.war /webapps/
RUN cp /experiments.bin /webapps/experiments.bin

FROM alpine:3.8
COPY --from=builder /webapps /webapps
