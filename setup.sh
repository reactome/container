# setup environment variable for getting tomcat password
if [[ -z "${TOMCAT_DOCKER_ENV_PASSWORD}" ]]; then
	echo "Set a password for docker:"
	read -s TOMCAT_DOCKER_ENV_PASSWORD
	echo "export TOMCAT_DOCKER_ENV_PASSWORD=$TOMCAT_DOCKER_ENV_PASSWORD" >>~/.bashrc
	. ~/.bashrc
	echo "Password has been set! Restart terminal/console"
else
	echo "Enter the password for docker:\n"
	read -s ENTERED_PASSWORD
	if [[ "$ENTERED_PASSWORD" == "$TOMCAT_DOCKER_ENV_PASSWORD" ]];
	then
		echo "Correct password"
	else
		echo "Incorrect password"
	fi
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

