#!/bin/bash
read -p "Build webapps? Press y/n" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "==========================================================================="
  echo "                   Building webapps using reactome-app-builder"
  echo "==========================================================================="
  cd ./java-application-builder
  ./build_webapps.sh
  cd ..
  echo "Reactome-app-builder exits here."
fi
echo
echo
echo "==========================================================================="
echo "Copying war files from java-application-builder/webapps to tomcat/webapps/"
echo "==========================================================================="
cp --verbose -u ./java-application-builder/webapps/*.war ./tomcat/webapps/
echo
echo
echo "==========================================================================="
echo "                        Starting docker containers"
echo "==========================================================================="
docker-compose up