set -a
source .env

# setup environment variable for getting tomcat password
if [[ -z "${TOMCAT_DOCKER_ENV_PASSWORD}" ]]; then
	echo "Set a password for tomcat:"
	read -s TOMCAT_DOCKER_ENV_PASSWORD_VALUE
	
	# write back the value collected here to .env file
	echo "TOMCAT_DOCKER_ENV_PASSWORD=$TOMCAT_DOCKER_ENV_PASSWORD_VALUE" >> .env
fi

# setup environment variable for getting MYSQL_ROOT_PASSWORD
if [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; then
	echo "Set a password for root user of MySQL database:"
	read -s MYSQL_ROOT_PASSWORD_VALUE
	
	# write back the value collected here to .env file
	echo "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD_VALUE" >> .env
fi

# add release as submodule to get various contents.
repo="release"
if [ ! -d $repo ]
then
  # Control will enter here if $DIRECTORY doesn't exist.
  # Add submodule Release
  echo "Creating :" $repo
  git submodule add https://github.com/reactome/$repo\
else
  # release already exists, so just update repository and discard local changes
  cd $repo
  echo "Discarding local changes to release"
  git fetch --all
  git reset --hard origin/master
  echo "Updating " $repo
  git pull origin master
  cd ..
fi
