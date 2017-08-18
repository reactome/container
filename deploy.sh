#!/bin/bash
set -e
# Update and download data archives.
# Following files will be downloaded:
#     - tomcat_sql_data named as gk_current_sql, located in mysql/tomcat_data
#     - Diagrams_and_fireworks.tgz located inside java-application-builder/downloads
#     - reactome.graphdb.tgz
#     - solr_data.tgz
function updateDataArchives()
{
  # Test for an active inernet connection
  echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1

  if [ $? -eq 0 ]; then
    # The first value in the list is the filepath in host directory and second value is the download link
    declare -A file_list
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
      # Creating a directory for the file to be downloaded
      mkdir -p $(dirname $file_path)

      if [ -f $file_path ] ; then
          # Get size information
          echo "Fetching metadata for remote file..."
          typeset -i remote_file_size=$(curl -sI $URL | tr -d '\r' | grep -i content-length | awk '{print $2}')
          typeset -i local_file_size=$(stat -c %s -- $file_path) > /dev/null 2>&1
          echo "#######################################################################"
          echo "# Filename:  " $file_name
          echo "#######################################################################"
          echo "Remote Size: " $remote_file_size
          echo "Local Size:  " $local_file_size

          if [[ $local_file_size -eq $remote_file_size ]]; then
            echo "Database up to date. Update not required"
          elif [[ $remote_file_size -eq 0 ]]; then
            echo "Remote file not acccessible. Could not update!"
          else
            echo "Database needs to be updated!"
            echo "Removing old file if it exists!"
            rm $file_path 2> /dev/null # 2> /dev/null is to ignore error if file not found
            echo "Downloading newer version"
            # To resume partially completed download, use --continue flag and comment out "rm $file_path 2> /dev/null"
            wget -O $file_path $URL
          fi
      else
        # For downloading file which does not exist locally
        echo "File $file_path does not exist. Will download now."
        wget -O $file_path $URL
      fi
      echo -e "\n\n"
    done
  else
    echo "No internet access! Not verifying databases!"
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
  declare -A file_list
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
        echo "Fetching metadata for remote file..."
        typeset -i remote_file_size=$(curl -sI $URL | tr -d '\r' | grep -i content-length | awk '{print $2}')
        typeset -i local_file_size=$(stat -c %s -- $file_path) > /dev/null 2>&1
        echo "#######################################################################"
        echo "# Filename:  " $file_name
        echo "#######################################################################"
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
  updateDataArchives
}

# Remove old archives and download new ones.
# Following files will be downloaded:
#     - interactors.db.gz
#     - analysis.bin.gz
#
# These files will get downloaded by downloadNewArchives
#     - tomcat_sql_data
#     - Diagrams_and_fireworks.tgz
#     - reactome.graphdb.tgz
#     - solr_data.tgz
function downloadAllNewArchives()
{
  declare -A file_list
  file_list+=( ["java-application-builder/downloads/analysis.bin.gz"]="https://reactome.org/download/current/analysis_v61.bin.gz" ) # Analysis.bin for analysis service
  file_list+=( ["java-application-builder/downloads/interactors.db.gz"]="https://reactome.org/download/current/interactors.db.gz" ) # interactors.db required to create analysis.bin
  
  for db_file in "${!file_list[@]}";
  do
    # Initialization before prepairing download
    URL=${file_list[${db_file}]}
    file_path=${db_file}
    file_name=$(basename $file_path)
    mkdir -p $(dirname $file_path)
    echo "#######################################################################"
    echo "# Filename:  " $file_name
    echo "#######################################################################"

    rm -rf $file_path
    echo "Old file deleted, downloading new one..."
    wget -O $file_path $URL
  done
  downloadNewArchives
}

# Following files will be downloaded:
#     - tomcat_sql_data named as gk_current_sql, located in mysql/tomcat_data
#     - Diagrams_and_fireworks.tgz located inside java-application-builder/downloads
#     - reactome.graphdb.tgz
#     - solr_data.tgz
function downloadNewArchives()
{
  declare -A file_list
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
    echo "#######################################################################"
    echo "# Filename:  " $file_name
    echo "#######################################################################"

    rm -rf $file_path
    echo "Old file deleted, downloading new one..."
    wget -O $file_path $URL
  done
}

function unpackArchives()
{
  echo -e "\n\n"
  echo "==========================================================================="
  echo "                           Unpacking required files"
  echo "==========================================================================="
  if [[ ! -f solr/data/solr_data/solr_data_extracted.flag ]]; then
    echo "Unpacking SolrData"
    rm -rf solr/solr_data
    tar -xvzf solr/data/solr_data.tgz -C solr/data
    touch solr/data/solr_data/solr_data_extracted.flag # 'Extracted' flag should reside inside the extracted folder
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
  if [[ ! -f diagrams_and_fireworks/diagrams_and_fireworks_extracted.flag ]]; then
    echo "Extracting diagrams and fireworks"
    rm -rf diagrams_and_fireworks
    set -e
    tar -xvzf diagrams_and_fireworks.tgz
    touch diagrams_and_fireworks/diagrams_and_fireworks_extracted.flag
    set +e

  else
    echo "Diagrams and fireworks already unpacked"
  fi

  if [[ ! -f interactors.db ]]; then
    echo "Extracting interactors.db"
    rm -rf interactors.db
    set -e
    gzip -dk interactors.db.gz
    set +e
  else
    echo "interactors.db already unpacked"
  fi

  if [[ ! -f analysis.bin ]]; then
    rm -rf analysis.bin
    echo "Extracting analysis.bin"
    set -e
    gzip -dk analysis.bin.gz
    touch analysis.bin_extracted.flag
    set +e
  else
    echo "analysis.bin already exists"
  fi
}

function startUp()
{
  cd "$(dirname "$0")"
  echo "Changing to current directory:$(pwd)"

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
    # this docker run is supposed to exit immidiately due to errors on startup, since we have not supplied root password
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


# Setting the currect working directory
cd "$(dirname "$0")"
thisScript="$0"
usage="
usage: $thisScript [option]... [argument]...
Every option can be accompanied by an argument, and flags are executed
in the order they are called.

Option          | Argument  | Description
------------------------------------------------------------------
-u, --update    | (No args)  If files are not present or not consistent 
                |            with their remote version, they will be
                |            downloaded. Update database files.
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
                |            - gk_current.sql.gz     : for mysql/tomcat
                |            - reactome.graphdb.tg   : for Neo4j
                |            - solr_data.tgz         : for Solr
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

-r, --run       | (No args)  Start the containers that run reactome server
                |            This should be last flag. Anything after this
                |            flag is not processed.
                |            Running deploy alone would also trigger the
                |            reactome server to start

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

numargs=$#
for ((i=1 ; i <= numargs ;))
do
  case "$1" in

    -d | --download)
      # Download option has been selected
      if [[ "$2" == "all" ]]; then
        echo "Selected 'all'. All previous archives, if present, will be deleted and new ones will be downloaded."
        downloadAllNewArchives
        # using shift to pop out 'all' argument
        ((i++));
        shift
      else
        echo "Switching to Default behavior: Only database archives will be removed and downloaded again."
        downloadNewArchives
      fi
      ;;

    -u | --update)
      # Update option has been selected.
      if [[ "$2" == "all" ]]; then
        echo "Selected 'all'. All previous archives will be checked. if inconsistent with remote version, new file will be downloaded."
        updateAllArchives
        ((i++));
        shift
      else
        echo "Switching to Default behavior: Only database archives will be updated."
        updateDataArchives
        echo "Archives updated"
      fi
      ;;

    -b | --build)
      # This is build option. Used to build webapps for tomcat
      declare -a app_list=(CuratorTool PathwayExchange RESTfulAPI PathwayBrowser SearchCore DataContent ContentService AnalysisToolsCore AnalysisToolsService AnalysisBin InteractorsCore)
      if [[ "$2" == "all" ]]; then
        echo "Selected all: These are all webapps which will be built:"
        for app_name in "${app_list[@]}"; do
          echo "${app_name}"
          export "state_${app_name}=develop"
        done
        ((i++));
        shift
      elif [[ "$2" == "select" ]]; then
        echo "Please select which applications you want to build: Press [y/n]"
        for app_name in "${app_list[@]}"; do
          echo
          read -p "${app_name}?`echo $'\n> '`" -n 1 -r
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            export "state_${app_name}=develop"
          else export "state_${app_name}=ready"
          fi
        done
        # Using shift to pop out 'select' argument
        ((i++));
        shift
      else
        echo "Default behavior: Only essential applications will be built"
        echo "Essential applications: ReactomeRESTfulAPI.war"
        export state_RESTfulAPI=develop
        echo "                        PathwayBrowser.war"
        export state_PathwayBrowser=develop
        echo "                        analysis-service.war"
        export state_AnalysisToolsService=develop
        echo "                        ContentService.war"
        export state_ContentService=develop
        echo "                        content.war"
        export state_DataContent=develop
      fi
      # Tell user whatever is going to happen next
      sleep 1
      # At this point we have determined which apps we want to build
      bash java-application-builder/build_webapps.sh |& tee logs/build_webapps.log
      ;;

    -h | --help )
      # Displaying help
      echo "$usage"
      exit 0
      ;;
    -r | --run )
      startUp
      exit
      ;;
    * )
      # Invalid option selected
      echo "$usage"
      echo "Invalid option: $1"
      exit
    esac
    # Using 'shift' to pop out the current option
    ((i++));
    shift
done
if [[ $numargs == 0 ]]; then
  # Only deploy is called, containers should be started
  startUp
  else
    # All flags have been processed, time to exit
    echo "Deploy script exiting..."
    exit 0
fi

