# Use PHP + Apache as the base layer.
FROM php:7.2.13-apache
RUN apt-get update
# Netcat is needed for waiting for database
RUN apt-get install -y netcat cpanminus wget \
	liblog-log4perl-perl libdbi-perl  libwww-search-perl \
	libtemplate-plugin-gd-perl libxml-simple-perl libcgi-pm-perl \
	libemail-valid-perl libpdf-api2-perl librtf-writer-perl \
	liburi-encode-perl libdbd-mysql-perl libjson-perl openssl curl
RUN cpanm Bio::Perl --notest
RUN ln -s /usr/bin/perl /usr/local/bin/perl
RUN docker-php-ext-install mysqli
COPY ./Website /var/www/html/
RUN chmod a+x /var/www/html/cgi-bin/*
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod proxy_html
RUN a2enmod cgi
RUN a2enmod headers
RUN a2enmod include
RUN mkdir /etc/apache2/ssl

# Create a self-signed certificate so SSL will work. Users should overwrite this with their own certs and keys.
WORKDIR /etc/apache2/ssl
RUN openssl genrsa -des3 -passout pass:xxxxx -out server.pass.key 2048
RUN openssl rsa -passin pass:xxxxx -in server.pass.key -out server.key
RUN openssl req -new -key server.key -out server.csr -subj "/C=XX/ST=SomePlace/L=SomePlace/O=SomeOrg/OU=SomeDepartment/CN=joomla-sites"
RUN openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
# RUN pwd && ls -lht
RUN rm server.csr && rm server.pass.key

RUN mkdir -p /var/www/html/download/current/
RUN mkdir -p /var/www/html/cgi-tmp/img-fp/gk_current/ && chmod a+rw /var/www/html/cgi-tmp/img-fp/gk_current/
ADD https://reactome.org/download/current/ehlds.tgz /var/www/html/download/current/ehld.tgz
RUN cd /var/www/html/download/current/ && tar -zxf ehld.tgz && echo "$(ls ./ehld | wc -l) items, $(du -hsxc ehld/* | tail -n 1) space used."
ADD https://reactome.org/download/current/ehld/svgsummary.txt /var/www/html/download/current/ehld/svgsummary.txt
RUN chmod a+r /var/www/html/download/current/ehld/svgsummary.txt
RUN mkdir -p /var/www/html/ehld-icons
ADD https://reactome.org/ehld-icons/icon-lib-svg.tgz /var/www/html/ehld-icons/icon-lib-svg.tgz
RUN cd /var/www/html/ehld-icons/ && tar -zxf icon-lib-svg.tgz && echo "$(du -hsxc lib/* | tail -n 1) space used."
ADD https://reactome.org/ehld-icons/icon-lib-emf.tgz /var/www/html/ehld-icons/icon-lib-emf.tgz
RUN cd /var/www/html/ehld-icons/ && tar -zxf icon-lib-emf.tgz && echo "$(du -hsxc lib/* | tail -n 1) space used."
ADD https://reactome.org/ehld-icons/icon-lib-png.tgz /var/www/html/ehld-icons/icon-lib-png.tgz
RUN cd /var/www/html/ehld-icons/ && tar -zxf icon-lib-png.tgz && echo "$(du -hsxc lib/* | tail -n 1) space used."
WORKDIR /var/www/html
# Set up some directories for PDF/RTF export.
RUN mkdir -p cgi-tmp/rtf && chown www-data:www-data cgi-tmp/rtf \
  && mkdir -p cgi-tmp/pdf && chown www-data:www-data cgi-tmp/pdf \
  && chown www-data:www-data ./cgi-tmp
