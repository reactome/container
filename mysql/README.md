# MySQL Docker image for Reactome

The files in this directory can be used to create a docker image which contains a MySQL database populated with Reactome data.

 - mysql.dockerfile - This file can be used to create a docker image containing Reactome MySQL data. When this dockerfile is used to build an image, it will download the Reactome MySQL main database dump from the reactome.org downloads page (https://reactome.org/download-data) and then load that into MySQL which runs inside the docker image. At the end of the process, a new docker image will be available which contains the MySQL data in a database named 'gk_current'.

 - init_db.sh - This script is used to load the data. It sets the data directory to be different from the standard data directory so that the data will persist even after the image is stopped.

 - init.sh - This script is used to set up some permissions when then image is used with docker-compose.
