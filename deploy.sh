#!/bin/bash
echo -e "\n\n"
echo "==========================================================================="
echo "                        Collecting databases"
echo "==========================================================================="
echo "Details of databases to be collected are:"
echo "In mysql-------------------------------------------------------------------"
echo "->mysql/tomcat_data/gk_current.sql.gz"
echo "->mysql/wordpress_data/reactome-wordpress.sql.gz"
echo
echo "In neo4j-------------------------------------------------------------------"
echo "->neo4j/data/reactome.graphdb.tgz"
# cd ./mysql/
URL_tomcat_db=http://www.reactome.org/download/current/databases/gk_current.sql.gz
URL_wordpress_db=http://www.reactome.org/download/current/databases/gk_wordpress.sql.gz
URL_neo4j_db=http://reactome.org/download/current/reactome.graphdb.tgz

echo "Initialting downloads..."
# wget --timestamping --directory-prefix=mysql/tomcat_data $URL_tomcat_db
# wget --timestamping --directory-prefix=mysql/wordpress_data $URL_wordpress_db
# wget --timestamping --directory-prefix=neo4j/data $URL_neo4j_db

remote_file_size=$(curl -sI $URL_tomcat_db | grep -i content-length | awk '{print $2}')
local_file_size=$(ls -l ./mysql/tomcat_data/gk_current.sql.gz | awk '{print $5}')
echo $remote_file_size
echo $local_file_size
echo "----------------------------------------------------------------------------"
if [[ "$local_file_size"=="$remote_file_size" ]]; then
    echo "Database up to date. Update not required"
else
    echo "Database needs to be updated!"
    wget --continue --directory-prefix=mysql/tomcat_data $URL_tomcat_db
fi
echo "-----------------------Script Under development-----------------------------"
exit

read -p "Build webapps? Press y/n" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo "==========================================================================="
  echo "                   Building webapps using reactome-app-builder"
  echo "==========================================================================="
  cd ./java-application-builder
  bash ./build_webapps.sh |& tee ../logs/build_webapps.log
  cd ..
  echo "Reactome-app-builder exits here."
fi

echo -e "\n\n"
echo "==========================================================================="
echo "Copying war files from java-application-builder/webapps to tomcat/webapps/"
echo "==========================================================================="
echo "Files to be copied:"
ls ./java-application-builder/webapps/
cp --verbose -u ./java-application-builder/webapps/*.war ./tomcat/webapps/
# Don't forget: also need the analysis.bin file for AnalysisService!
cp --verbose -u ./java-application-builder/webapps/analysis.bin ./tomcat/webapps/

echo -e "\n\n"
echo "==========================================================================="
echo "                        Starting docker containers"
echo "==========================================================================="
docker-compose up
docker-compose down
