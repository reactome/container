# Joomla docker image for Reactome

The files in this directory can be used to create a docker image for Reactome that contains Joomla, and other components to run Reactom's Joomla CMS.

 - joomla.dockerfile - This file describes how the Joomla image is to be built. It is based on a PHP image. The Joomla files are located in Website, which is a submodule reference to [Website](https://github.com/reactome/Website), so be sure to pull the contents of this submodule! This file will also contain modified versions of some Reactome Perl CGI scripts - these are located in `cgi-bin` and `cgi-modules`. One thing this image does _not_ contain is the Joomla database. Docker compose will load that into a separate container running MySQL.
