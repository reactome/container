FROM wordpress
RUN apt-get update && apt-get install -y \
    netcat cpanminus \
    liblog-log4perl-perl libdbi-perl  libwww-search-perl \
    libtemplate-plugin-gd-perl libxml-simple-perl libcgi-pm-perl \
    libemail-valid-perl libpdf-api2-perl librtf-writer-perl \
    liburi-encode-perl
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get autoremove
RUN  cpanm Bio::Perl --notest
RUN ln -s /usr/local/gkb/modules/ /usr/modules
