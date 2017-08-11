#!/bin/bash

# Update and download data archives.
# Following files will be downloaded:
#     - tomcat_sql_data named as gk_current_sql, located in mysql/tomcat_data
#     - Diagrams_and_fireworks.tgz located inside java-application-builder/downloads
#     - reactome.graphdb.tgz
#     - solr_data.tgz
function updateDataArchives()
{
  # Test for an active inernet connection
  if [[ $1 == "-u" ]]; then
    echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1

    if [ $? -eq 0 ]; then
      echo -e "\n\n"
      echo "Initiating download"
      echo "========================================================================="
      echo "                           Verifying databases"
      echo "========================================================================="
      echo "Details of databases to be collected are:"
      echo "-------------------------------------------------------------------------"

      # wordpress_data is a smaller database and its modified version is available in the repo itself.
      echo "->mysql/wordpress_data/reactome-wordpress.sql.gz"
      echo "->mysql/tomcat_data/gk_current.sql.gz"
      echo "->neo4j/data/reactome.graphdb.tgz"
      echo "->solr/data/solr_data.tgz"
      echo "->java-application-builder/downloads/analysis.bin.gz"
      echo "->java-application-builder/downloads/interactors.db.gz"
      echo "-------------------------------------------------------------------------"

      # The first value in the list is the filepath in host directory and second value is the download link
      local declare -A file_list
      file_list+=( ["mysql/tomcat_data/gk_current.sql.gz"]="http://www.reactome.org/download/current/databases/gk_current.sql.gz" ) # tomcat_data
      file_list+=( ["neo4j/data/reactome.graphdb.tgz"]="http://reactome.org/download/current/reactome.graphdb.tgz" ) # neo4j data
      file_list+=( ["solr/data/solr_data.tgz"]="https://reactome.org/download/current/solr_data.tgz" ) # solr data
      file_list+=( ["java-application-builder/downloads/diagrams_and_fireworks.tgz"]="https://reactome.org/download/current/diagrams_and_fireworks.tgz" )
      # file_list+=( ["mysql/wordpress_data/reactome-wordpress.sql.gz"]="http://www.reactome.org/download/current/databases/gk_wordpress.sql.gz")

      for db_file in "${!file_list[@]}";
      do
        # Initialization before prepairing download
        URL=${file_list[${db_file}]}
        file_path=${db_file}
        file_name=$(basename $file_path)
        mkdir -p $(dirname $file_path)

        if [ -f $file_path ] ; then
            # Get size information
            typeset -i remote_file_size=$(curl -sI $URL | tr -d '\r' | grep -i content-length | awk '{print $2}')
            typeset -i local_file_size=$(stat -c %s -- $file_path) > /dev/null 2>&1
            echo "======================================================================="
            echo "======================================================================="
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
        else
            echo "File $file_path does not exist. Will download now."
            wget -O $file_path $URL
        fi
        echo -e "\n\n"
      done
    else
      echo "No internet access! Not verifying databases!"
    fi
  fi
}

# Update and download data archives.
# Following files will be downloaded:
#     - interactors.db.gz
#     - analysis.bin.gz
#
# These files will get downloaded by updateDataArchives
#     - tomcat_sql_data
#     - Diagrams_and_fireworks.tgz
#     - reactome.graphdb.tgz
#     - solr_data.tgz
function updateAllArchives()
{
  updateDataArchives
  local declare -A file_list
  file_list+=( ["java-application-builder/downloads/analysis.bin.gz"]="https://reactome.org/download/current/analysis_v61.bin.gz" ) # Analysis.bin for analysis service
  file_list+=( ["java-application-builder/downloads/interactors.db.gz"]="https://reactome.org/download/current/interactors.db.gz" ) # interactors.db required to create analysis.bin
  for db_file in "${!file_list[@]}";
  do
    # Initialization before prepairing download
    URL=${file_list[${db_file}]}
    file_path=${db_file}
    file_name=$(basename $file_path)
    mkdir -p $(dirname $file_path)

    if [ -f $file_path ] ; then
        # Get size information
        typeset -i remote_file_size=$(curl -sI $URL | tr -d '\r' | grep -i content-length | awk '{print $2}')
        typeset -i local_file_size=$(stat -c %s -- $file_path) > /dev/null 2>&1
        echo "======================================================================="
        echo "======================================================================="
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
    else
        echo "File $file_path does not exist. Will download now."
        wget -O $file_path $URL
    fi
    echo -e "\n\n"
  done
}

# Remove old archives and download new ones.
#
function downloadAllNewArchives()
{
  downloadNewArchives
  local declare -A file_list
  file_list+=( ["java-application-builder/downloads/analysis.bin.gz"]="https://reactome.org/download/current/analysis_v61.bin.gz" ) # Analysis.bin for analysis service
  file_list+=( ["java-application-builder/downloads/interactors.db.gz"]="https://reactome.org/download/current/interactors.db.gz" ) # interactors.db required to create analysis.bin
  
  for db_file in "${!file_list[@]}";
  do
    # Initialization before prepairing download
    URL=${file_list[${db_file}]}
    file_path=${db_file}
    file_name=$(basename $file_path)
    mkdir -p $(dirname $file_path)

    rm -rf $file_path
    wget -O $file_path $URL
  done
}


function downloadNewArchives()
{
  local declare -A file_list
  file_list+=( ["mysql/tomcat_data/gk_current.sql.gz"]="http://www.reactome.org/download/current/databases/gk_current.sql.gz" ) # tomcat_data
  file_list+=( ["neo4j/data/reactome.graphdb.tgz"]="http://reactome.org/download/current/reactome.graphdb.tgz" ) # neo4j data
  file_list+=( ["solr/data/solr_data.tgz"]="https://reactome.org/download/current/solr_data.tgz" ) # solr data
  file_list+=( ["java-application-builder/downloads/diagrams_and_fireworks.tgz"]="https://reactome.org/download/current/diagrams_and_fireworks.tgz" )
  for db_file in "${!file_list[@]}";
  do
    # Initialization before prepairing download
    URL=${file_list[${db_file}]}
    file_path=${db_file}
    file_name=$(basename $file_path)
    mkdir -p $(dirname $file_path)

    rm -rf $file_path
    wget -O $file_path $URL
  done
}

function unpackArchives()
{
  echo -e "\n\n"
  echo "==========================================================================="
  echo "                           Unpacking required files"
  echo "==========================================================================="
  if [[ ! -f solr/data/solr_data_extracted.flag ]]; then
    echo "Unpacking SolrData"
    rm -rf solr/solr_data
    tar -xvzf solr/data/solr_data.tgz -C solr/data
    touch solr/data/solr_data_extracted.flag
    chmod a+w solr/data/solr_data/reactome
    chmod a+w solr/data/solr_data/reactome/data
    chmod a+w solr/data/solr_data/reactome/data/index/write.lock
    chmod a+w solr/data/solr_data/reactome/data/index
    chmod a+w -R solr/data/solr_data/reactome/data/tlog
    mkdir -p logs/solr
    chmod a+w logs/solr

  else
    echo "solr_data already unpacked"
  fi

  echo "Changing directory to: "
  cd java-application-builder/downloads
  pwd
  if [[ ! -f diagrams_and_fireworks_extracted.flag ]]; then
    echo "Extracting diagrams and fireworks"
    rm -rf diagrams_and_fireworks
    set -e
    tar -xvzf diagrams_and_fireworks.tgz
    touch diagrams_and_fireworks_extracted.flag
    set +e

  else
    echo "Diagrams and fireworks already unpacked"
  fi

  if [[ ! -f interactorsdb_extracted.flag ]]; then
    echo "Extracting interactors.db"
    rm -rf interactors.db
    set -e
    gzip -dk interactors.db.gz
    touch interactorsdb_extracted.flag
    set +e
  else
    echo "interactors.db already unpacked"
  fi

  if [[ ! -f analysis.bin_extracted.flag ]]; then
    rm -rf analysis.bin
    echo "Extracting analysis.bin"
    set -e
    gzip -dk analysis.bin.gz
    touch analysis.bin_extracted.flag
    set +e
  else
    echo "analysis.bin already unpacked"
  fi
}

function startUp()
{
  echo "Changing directory to:"
  cd ../..
  pwd

  read -p "Build webapps? Press [y/n]" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo
    echo "========================================================================="
    echo "                Building webapps using reactome-app-builder"
    echo "========================================================================="
    cd ./java-application-builder
    bash ./build_webapps.sh |& tee ../logs/build_webapps.log
    cd ..
    echo "Reactome-app-builder exits here."
  fi

  echo -e "\n\n"
  echo "==========================================================================="
  echo "                      Linking mysql Logs"
  echo "==========================================================================="

  # Link mysql logs
  mkdir -p ./logs/mysql/wordpress
  mkdir -p ./logs/mysql/tomcat
  sudo chown -vR 999:999 ./logs/mysql
  owner=$(ls -ld ./logs/mysql | awk 'NR==1 {print $3}')
  if ! [[ $owner == 999 || $owner == 'mysql' ]]; then
    # Permissions remain unchanged, logs will reside in internal docker volumes
    # if it is first run of this script, volumes do not exist, we need to create them before providing its link
    # this docker run will exit immidiately due to errors on startup, since we have not supplied root password
    docker run --rm -itd \
    -v "container_mysql-for-tomcat-log:/random/location" \
    -v "container_mysql-for-wordpress-log:/another/random" mysql:5.7

    # Volumes are created, now we can link those volumes to /backup inside container
    sudo ln -s $(docker volume inspect --format '{{ .Mountpoint }}' container_mysql-for-tomcat-log) $(pwd)/logs/mysql/wordpress/Link_to_internal_log
    sudo ln -s $(docker volume inspect --format '{{ .Mountpoint }}' container_mysql-for-wordpress-log) $(pwd)/logs/mysql/tomcat/Link_to_internal_log
    # Use sudo to view content inside the linked directory.
  fi

  echo -e "\n\n"
  echo "==========================================================================="
  echo "                        Starting docker containers"
  echo "==========================================================================="
  docker-compose up
  # docker-compose down
}


usage="
usage: $thisScript [option]... [argument]...
Giving arguments to options is not mandatory.

Option          | Argument  | Description
------------------------------------------------------------------
-u, --update    | (No args)  Update database files.
                |            The files that will be updated include:
                |            - gk_current.sql.gz    : for mysql/tomcat
                |            - reactome.graphdb.tg  : for Neo4j
                |            - solr_data.tgz        : for Solr
                |            - diagrams_and_fireworks.tgz
                |
                | all        Using 'all' argument would update those
                |            files also which can be built locally.
                |            Like: 
                |            - analysis.bin
                |            - interactors.db

-d, --download  | (No args)  Remove old and download new database files
                |            It operates sequentially on each file
                |            Following files will be downloaded:
                |            - gk_current.sql.gz    : for mysql/tomcat
                |            - reactome.graphdb.tg  : for Neo4j
                |            - solr_data.tgz        : for Solr
                |            - diagrams_and_fireworks.tgz
                |
                | all        Using 'all' argument would also download
                |            those files which can be built locally.
                |            Like: 
                |            - analysis.bin
                |            - interactors.db

-b, --build     | (No args)  Build essential java web applications.
                |            Following applications will be built:
                |            - CuratorTool
                |            - PathwayExchange
                |            - RESTfulAPI
                |            - PathwayBrowser
                |            - DataContent
                |            - ContentService
                |            - AnalysisToolsCore
                |
                | all        Builds all the java applications and files
                |            These additinal applications will be built
                |            - AnalysisBin
                |            - InteractorsCore
                |            - AnalysisToolsService
                |
                | select     You will be provided with prompts to select
                |            which applications you want to build.

Example: $thisScript
       : $thisScript -d -b
       : $thisScript -d all -b
       : $thisScript -d all -b all
       : $thisScript --build --download
       : $thisScript --build all --download all
  -b      Build webapps
  -d      Download Archives
  -h      display help
"

# Setting the currect working directory
cd "${0%/*}"
thisScript="$0"
echo "Now executing the script"
numargs=$#
for ((i=1 ; i <= numargs ; i++))
do
  case "$1" in
    -d | --download)
      # This is the download option
      if [[ "$2" == "all" ]]; then
        echo "Selected 'all'. All previous archives, if present, will be deleted and new ones will be downloaded."
        shift
      else
        echo "Switching to Default behavior: Only database archives will be removed and downloaded again."
      fi
      ;;
    -b | --build)
      # This is build option. Used to build webapps for tomcat
      if [[ "$2" == "all" ]]; then
        echo "Selected all: All webapps will be built"
        shift
      elif [[ "$2" == "select" ]]; then
        echo "Please select which applications you want to build:"
        shift
      else
        echo "Default behavior: 'Build' will switch to its default behavior and only essential applications will be built"
        echo "Essential applications: ReactomeRESTfulAPI.war"
        echo "                        PathwayBrowser.war"
        echo "                        analysis-service.war"
        echo "                        ContentService.war"
        echo "                        content.war"
      fi
      ;;
    -h | --help)
      # Displaying help
      echo $usage
    esac
    shift
done