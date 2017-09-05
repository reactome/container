# setup environment variable for getting tomcat password
echo "Which username and passwords you wish to change(Press 'y' for yes):"
read -p "Mysql for Tomcat users?`echo $'\n> '`" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # # Change username (We need not create a new user in mysql)
  # read -p "`echo`Enter new Username`echo $'\n> '`"
  # user_of_mysql_for_tomcat=$REPLY
  
  # Change password
  read -p "Enter new password`echo $'\n> '`"
  password_of_mysql_for_tomcat=$REPLY

  # Update tomcat.env
  sed -i "/MYSQL_ROOT_PASSWORD=/ s/=.*/=${password_of_mysql_for_tomcat}/" tomcat.env # https://stackoverflow.com/a/5955623/6207775 and https://stackoverflow.com/a/19152051/6207775
  echo "Updated tomcat.env"

  # Update java-application-builder/mounts/applicationContext.xml
  # This update step requires applicationContext.xml to be constant
  replace="      <constructor-arg index=\"2\" value=\"$user_of_mysql_for_tomcat\"/> <!-- username was reactome_user -->"
  sed -i "13s|.*|${replace}|" ./java-application-builder/mounts/applicationContext.xml # from https://stackoverflow.com/questions/11145270/bash-replace-an-entire-line-in-a-text-file
  replace="      <constructor-arg index=\"3\" value=\"$password_of_mysql_for_tomcat\"/> <!-- password was reactome_pass -->"
  sed -i "14s|.*|${replace}|" ./java-application-builder/mounts/applicationContext.xml # from https://stackoverflow.com/questions/11145270/bash-replace-an-entire-line-in-a-text-file
  echo "Updated applicationContext.xml"
  
  # Update java-application-builder/maven_builds.sh#L89
  sed -i "/MYSQL_ROOT_PASSWORD=/ s/=.*/=${password_of_mysql_for_tomcat}/" java-application-builder/maven_builds.sh
  echo "Updated maven_builds.sh"

  exit 0
fi

# We currently don't need this function
function createNewMysqlUser()
{
  # Find if user exists
  grep -q MYSQL_USER tomcat.env
  if [ $? -eq 0 ]
  then
    # Update username
    sed -i "/MYSQL_USER=/ s/=.*/=${user_of_mysql_for_tomcat}/" tomcat.env
    # Update Password
    sed -i "/MYSQL_PASSWORD=/ s/=.*/=${password_of_mysql_for_tomcat}/" tomcat.env
  else
    # Create a new user
    echo "MYSQL_USER=$user_of_mysql_for_tomcat" >> tomcat.env
    echo "MYSQL_PASSWORD=$password_of_mysql_for_tomcat" >> tomcat.env
  fi
  echo "New User for mysql creaeted in tomcat.env"
}
