FROM tomcat:7-jre8
RUN apt-get update && apt-get install -y \
    netcat \
  && rm -rf /var/lib/apt/lists/*
# COPY ./webapps/*.war /usr/local/tomcat/webapps/
