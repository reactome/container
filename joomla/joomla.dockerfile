# Use PHP + Apache as the base layer.
FROM php:7.2.1-apache
RUN apt-get update
# Netcat is needed for waiting for database
RUN apt-get install -y netcat cpanminus wget \
	liblog-log4perl-perl libdbi-perl  libwww-search-perl \
	libtemplate-plugin-gd-perl libxml-simple-perl libcgi-pm-perl \
	libemail-valid-perl libpdf-api2-perl librtf-writer-perl \
	liburi-encode-perl libdbd-mysql-perl curl
RUN cpanm Bio::Perl --notest
RUN ln -s /usr/bin/perl /usr/local/bin/perl
RUN docker-php-ext-install mysqli
COPY ./Website /var/www/html/
RUN chmod a+x /var/www/html/cgi-bin/*
RUN a2enmod rewrite
RUN apt-get install openssl -y
RUN a2enmod ssl
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod proxy_html
RUN mkdir /etc/apache2/ssl

# Create a self-signed certificate so SSL will work. Users should overwrite this with their own certs and keys.
WORKDIR /etc/apache2/ssl
RUN openssl genrsa -des3 -passout pass:xxxxx -out server.pass.key 2048
RUN openssl rsa -passin pass:xxxxx -in server.pass.key -out server.key
RUN openssl req -new -key server.key -out server.csr -subj "/C=XX/ST=SomePlace/L=SomePlace/O=SomeOrg/OU=SomeDepartment/CN=joomla-sites"
RUN openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
# RUN pwd && ls -lht
RUN rm server.csr && rm server.pass.key
