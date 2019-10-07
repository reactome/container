FROM maven:3.6.0-jdk-8 AS builder
LABEL maintainer="solomon.shorser@oicr.on.ca"
RUN mkdir /webapps
RUN mkdir /gitroot
COPY ./java-build-mounts/settings-docker.xml /mvn-settings.xml
RUN mkdir -p /mvn/alt-m2/
ENV MVN_CMD "mvn --global-settings /mvn-settings.xml -Dmaven.repo.local=/mvn/alt-m2/"


ENV DATA_CONTENT_VERSION=da21f0f1541110ccd861ea9845a631093ee08172
RUN cd /gitroot/ && git clone https://github.com/reactome/data-content.git \
  && cd /gitroot/data-content \
  && git checkout $DATA_CONTENT_VERSION

# The TLD files cannot be in the tags directory. Tomcat was throwing errors about this.
# The solution is to move or rename the TLD files. I'm moving them to "custom-tags".
# See: https://stackoverflow.com/q/38593625 or section 7.3.1 in:
# https://download.oracle.com/otn-pub/jcp/jsp-2.2-mrel-oth-JSpec/jsp-2_2-mrel-spec.pdf?AuthParam=1548101315_d5c1a23b8f143b2f92e27a656a477f79
WORKDIR /gitroot/data-content
RUN cp -a src/main/webapp/WEB-INF/tags src/main/webapp/WEB-INF/custom-tags
# Update files that were referencing customTag.tld or sortTag.tld
RUN { for f in $(grep -RIH \/tags\/customTag.tld . | cut -d ':' -f 1) ; do echo "fixing customTag.tld path in  $f" ; sed -i -e 's/tags/custom-tags/g' $f ; done ; }
RUN { for f in $(grep -RIH \/tags\/sortTag.tld . | cut -d ':' -f 1) ; do echo "fixing sortTag.tld path in  $f" ; sed -i -e 's/tags/custom-tags/g' $f ; done ; }

RUN echo "Files still referencing tags/customTag.tld" && grep -RIH \/tags\/customTag.tld . | cut -d ':' -f 1
RUN echo "Files still referencing tags/sortTag.tld" && grep -RIH \/tags\/sortTag.tld . | cut -d ':' -f 1

RUN cd src/main/resources && sed -i -e 's/<\/configuration>/<logger name="org.apache" level="WARN"\/><logger name="httpclient" level="WARN"\/><\/configuration>/g' logback.xml
RUN cd /gitroot/data-content && sed -i -e 's/<reactome\.search\.core>1\.2\.0-SNAPSHOT<\/reactome\.search\.core>/<reactome.search.core>1.3.0-SNAPSHOT<\/reactome.search.core>/g' pom.xml
RUN $MVN_CMD clean compile package install -P DataContent-Local \
    && cp /gitroot/data-content/target/content*.war /webapps/content.war && du -hscx /mvn/alt-m2/

FROM alpine:3.8
COPY --from=builder /webapps/content.war /webapps/content.war
