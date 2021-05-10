# Build as:
#    docker build -t reactome/reactome-mysql:R67 -f mysql.dockerfile .
# Run as:
#    docker run --rm -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=gk_current reactome/reactome-mysql:R67
FROM mysql:5.7.24
ARG MYSQL_ROOT_PASSWORD=root
ARG RELEASE_VERSION=Release74
LABEL ReleaseVersion ${RELEASE_VERSION}
WORKDIR /docker-entrypoint-initdb.d
RUN apt-get update && apt-get install wget netcat pigz -y
# TODO: Maybe we should include the stable_identifiers database as well?
# Get the zipped data
RUN wget -nv https://reactome.org/download/current/databases/gk_current.sql.gz && \
	unpigz gk_current.sql.gz && \
	mv gk_current.sql current.sql && \
	mkdir /extra_stuff

ENV MYSQL_DATABASE=current
ENV MYSQL_ROOT_PASSWORD=root

COPY ./wait-for.sh /extra_stuff/wait-for.sh
# Load the data
COPY ./init_db.sh /extra_stuff/init_db.sh
RUN chmod a+x /extra_stuff/wait-for.sh && \
	mkdir -p /data/mysql && \
	cat /etc/mysql/my.cnf && \
	bash /extra_stuff/init_db.sh
