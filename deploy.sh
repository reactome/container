#!/bin/bash
echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "Online"
  echo -e "\n\n"
  echo "==========================================================================="
  echo "                           Verifying databases"
  echo "==========================================================================="
  echo "Details of databases to be collected are:"
  echo "---------------------------------------------------------------------------"
  # wordpress_data is a smaller database and its modified version is available in the repo itself.
  echo "->mysql/wordpress_data/reactome-wordpress.sql.gz"
  echo "->mysql/tomcat_data/gk_current.sql.gz"
  echo "->neo4j/data/reactome.graphdb.tgz"
  echo "->solr/data/solr_data.tgz"
  echo "->java-application-builder/downloads/analysis_v61.bin.gz"
  echo "->java-application-builder/downloads/interactors.db.gz"
  echo "---------------------------------------------------------------------------"

  # The first value in the list is the filepath in host directory and second value is the download link
  declare -A file_list
  file_list+=( ["mysql/tomcat_data/gk_current.sql.gz"]="http://www.reactome.org/download/current/databases/gk_current.sql.gz" ) # tomcat_data
  file_list+=( ["neo4j/data/reactome.graphdb.tgz"]="http://reactome.org/download/current/reactome.graphdb.tgz" ) # neo4j data
  file_list+=( ["solr/data/solr_data.tgz"]="https://reactome.org/download/current/solr_data.tgz" ) # solr data
  file_list+=( ["java-application-builder/downloads/analysis_v61.bin.gz"]="https://reactome.org/download/current/analysis_v61.bin.gz" ) # Analysis.bin for analysis service
  file_list+=( ["java-application-builder/downloads/interactors.db.gz"]="https://reactome.org/download/current/interactors.db.gz" ) # interactors.db required to create analysis.bin
  file_list+=( ["java-application-builder/downloads/diagrams_and_fireworks.tgz"]="https://reactome.org/download/current/diagrams_and_fireworks.tgz" )
  # file_list+=( ["mysql/wordpress_data/reactome-wordpress.sql.gz"]="http://www.reactome.org/download/current/databases/gk_wordpress.sql.gz")

  for db_file in "${!file_list[@]}";
  do
    # Initialization before prepairing download
    URL=${file_list[${db_file}]}
    file_path=${db_file}
    file_name=$(basename $file_path)
    mkdir -p $(dirname $file_path)

    # Get size information
    typeset -i remote_file_size=$(curl -sI $URL | tr -d '\r' | grep -i content-length | awk '{print $2}')
    typeset -i local_file_size=$(stat -c %s -- $file_path)
    echo "==========================================================================="
    echo "==========================================================================="
    echo "Filename:    " $file_name
    echo "Remote Size: " $remote_file_size
    echo "Local Size:  " $local_file_size

    if [[ $local_file_size -eq $remote_file_size ]]; then
        echo "Database up to date. Update not required"
    elif [[ $remote_file_size -eq 0 ]]; then
        echo "Remote file not acccessible. Not updating!"
    else
      echo "Database needs to be updated!"
      echo "Removing old file if it exists!"
      rm $file_path 2> /dev/null # 2> /dev/null is to ignore error if file not found
      echo "Downloading newer version"
      # To resume partially completed download, use --continue flag and comment out "rm $file_path 2> /dev/null"
      wget -O $file_path $URL
    fi
    echo
    echo
  done
else
    echo "No internet access! Not verifying databases!"
fi

read -p "Build webapps? Press [y/n]" -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo
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
