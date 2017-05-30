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