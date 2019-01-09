FROM maven:3.6.0-jdk-8 AS builder

RUN mkdir -p /gitroot
WORKDIR /gitroot
LABEL maintainer="solomon.shorser@oicr.on.ca"
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
RUN mkdir /webapps
ENV MVN_CMD "mvn --global-settings  /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"

ENV DATA_CONTENT_VERSION=master
RUN cd /gitroot/ && git clone https://github.com/reactome/data-content.git \
  && cd /gitroot/data-content \
  && git checkout $DATA_CONTENT_VERSION

# COPY ./properties/data-content.ogm.properties /gitroot/data-content/src/main/resources/ogm.properties
# COPY ./properties/data-content.service.properties /gitroot/data-content/src/main/resources/core.properties

WORKDIR /gitroot/data-content
RUN mv src/main/webapp/WEB-INF/tags/customTag.tld src/main/webapp/WEB-INF/tags/implicit.tld
RUN { for f in $(grep -RIH customTag.tld . | cut -d ':' -f 1) ; do echo "fixing customTag.tld name in  $f" ; sed -i -e 's/customTag\.tld/implicit.tld/g' $f ; done ; }

RUN echo "Files still referencing customTag.tld" && grep -RH customTag.tld . | cut -d ':' -f 1

RUN cd src/main/resources && sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml
RUN cd /gitroot/data-content && sed -i -e 's/<reactome\.search\.core>1\.2\.0-SNAPSHOT<\/reactome\.search\.core>/<reactome.search.core>1.3.0-SNAPSHOT<\/reactome.search.core>/g' pom.xml
RUN $MVN_CMD clean compile package install -P DataContent-Local \
    && cp /gitroot/data-content/target/content*.war /webapps/content.war && du -hscx /mvn/alt-m2/
