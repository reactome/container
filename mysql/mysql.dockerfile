# Build as:
#    docker build -t reactome/reactome-mysql:R67 -f mysql.dockerfile .
# Run as:
#    docker run --rm -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=gk_current reactome/reactome-mysql:R67
FROM mysql:5.7.24
ARG MYSQL_ROOT_PASSWORD=root
ARG RELEASE_VERSION=R71
LABEL ReleaseVersion ${RELEASE_VERSION}
WORKDIR /docker-entrypoint-initdb.d
RUN apt-get update && apt-get install wget netcat pigz -y
# TODO: Maybe we should include the stable_identifiers database as well?
# Get the zipped data
RUN wget -nv https://reactome.org/download/current/databases/gk_current.sql.gz
RUN ls -lht
RUN unpigz gk_current.sql.gz && mv gk_current.sql current.sql
RUN ls -lht
ENV MYSQL_DATABASE=current
ENV MYSQL_ROOT_PASSWORD=root
RUN mkdir /extra_stuff
COPY ./wait-for.sh /extra_stuff/wait-for.sh
RUN chmod a+x /extra_stuff/wait-for.sh
# Load the data
COPY ./init_db.sh /extra_stuff/init_db.sh
RUN mkdir -p /data/mysql
RUN cat /etc/mysql/my.cnf
RUN bash /extra_stuff/init_db.sh
