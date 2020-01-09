# Use PHP + Apache as the base layer.
FROM php:7.2.13-apache
# Install some packages we'll need.
RUN apt-get update && apt-get install -y netcat cpanminus wget \
	liblog-log4perl-perl libdbi-perl  libwww-search-perl \
	libtemplate-plugin-gd-perl libxml-simple-perl libcgi-pm-perl \
	libemail-valid-perl libpdf-api2-perl librtf-writer-perl \
	liburi-encode-perl libdbd-mysql-perl libjson-perl openssl curl && apt-get autoremove && \
	cpanm Bio::Perl --notest && \
	ln -s /usr/bin/perl /usr/local/bin/perl && \
	docker-php-ext-install mysqli
COPY ./Website /var/www/html/
RUN chmod a+x /var/www/html/cgi-bin/* && \
	a2enmod rewrite && \
	a2enmod ssl && \
	a2enmod proxy && \
	a2enmod proxy_http && \
	a2enmod proxy_html && \
	a2enmod cgi && \
	a2enmod headers && \
	a2enmod include && \
	mkdir /etc/apache2/ssl

# Create a self-signed certificate so SSL will work. Users should overwrite this with their own certs and keys.
WORKDIR /etc/apache2/ssl
RUN openssl genrsa -des3 -passout pass:xxxxx -out server.pass.key 2048 && \
	openssl rsa -passin pass:xxxxx -in server.pass.key -out server.key && \
	openssl req -new -key server.key -out server.csr -subj "/C=XX/ST=SomePlace/L=SomePlace/O=SomeOrg/OU=SomeDepartment/CN=joomla-sites" && \
	openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt && \
	rm server.csr && rm server.pass.key

RUN mkdir -p /var/www/html/download/current/ && mkdir -p /var/www/html/Icons && mkdir -p /var/www/html/ehld-icons && \
	mkdir -p /var/www/html/cgi-tmp/img-fp/current/ && chmod a+rw /var/www/html/cgi-tmp/img-fp/current/
ADD https://reactome.org/download/current/ehlds.tgz /var/www/html/download/current/ehld.tgz
RUN cd /var/www/html/download/current/ && tar -zxf ehld.tgz && echo "$(ls ./ehld | wc -l) items, $(du -hsxc ehld/* | tail -n 1) space used."
ADD https://reactome.org/download/current/ehld/svgsummary.txt /var/www/html/download/current/ehld/svgsummary.txt
RUN chmod a+r /var/www/html/download/current/ehld/svgsummary.txt
ADD https://reactome.org/icon/icon-lib-svg.tgz /var/www/html/Icons/icon-lib-svg.tgz
RUN cd /var/www/html/Icons/ && tar -zxf icon-lib-svg.tgz && rm icon-lib-svg.tgz
ADD https://reactome.org/icon/icon-lib-emf.tgz /var/www/html/Icons/icon-lib-emf.tgz
RUN cd /var/www/html/Icons/ && tar -zxf icon-lib-emf.tgz && rm icon-lib-emf.tgz
ADD https://reactome.org/icon/icon-lib-png.tgz /var/www/html/Icons/icon-lib-png.tgz
RUN cd /var/www/html/Icons/ && tar -zxf icon-lib-png.tgz && rm icon-lib-png.tgz

WORKDIR /var/www/html
# Set up some directories for PDF/RTF export.
RUN mkdir -p cgi-tmp/rtf && chown www-data:www-data cgi-tmp/rtf \
	&& mkdir -p cgi-tmp/pdf && chown www-data:www-data cgi-tmp/pdf \
	&& chown www-data:www-data ./cgi-tmp
