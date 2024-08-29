#!/bin/bash
# ScriptName: pocket-guacamole.sh
# v1.1.0
# Tested on: RedOS 7.3.4

# User list
declare -A users_dict=(
["student001"]="rocket"
["student002"]="trumpet"
["student003"]="9x3f45g"
)

# SSH server list
declare -A servers_dict=(
["SSH RedOS-7.3.4"]="192.168.130.64"
["SSH RedOS-7.3.3"]="192.168.130.63"
)

USER_MAPPING_FILE=/etc/guacamole/user-mapping.xml
GUACD_FILE=/etc/guacamole/guacd.conf
GUACAMOLE_PROP_FILE=/etc/guacamole/guacamole.properties


# === TECHNICAL VARS ===
CLEAR_COLOR="\033[0m"
RED_COLOR="\033[31m"
GREEN_COLOR="\033[32m"


# === SCRIPT SUPPORT FUNCTIONS ===
function check_file()
{
	if [ ! -f $2 ]; then
        echo -e "$RED_COLOR Error! $1 file $2 not exist... $CLEAR_COLOR"
		exit 2
    fi
    fail_ok "File exist $1"
}

function fail_ok()
{
    if [ $? -eq 0 ];then
        echo -ne "[${GREEN_COLOR}OK${CLEAR_COLOR}] $1"
        echo
    else
        echo -ne "[${RED_COLOR}fail${CLEAR_COLOR}] $1"
        echo
    fi
}

function checkService() {
# Service is exists?
systemctl status $1 > /dev/null 2>&1
STATUS=$?
if [[ $STATUS -eq 0 ]]; then
	# Check service status
	echo -ne "$1 : $GREEN_COLOR";  systemctl is-active $1
	echo -ne "$CLEAR_COLOR"
elif [[ $STATUS -eq 3 ]]; then
	echo -ne "$1 : $RED_COLOR";  systemctl is-active $1
	echo -ne "$CLEAR_COLOR"
fi
}

# === SCRIPT ===
function install()
{

	echo "Did you fill all variables?"
	read -p "Continue? (y/n): " USER_CONFIRM
	
	if [[ ! $USER_CONFIRM == "y" ]]; then
		echo "Then fill vars"
		exit 1
	fi

	yum install guacd libguac-client-rdp libguac-client-ssh libguac-client-vnc libguac-client-telnet tomcat tomcat-webapps -y
	
	mkdir /etc/guacamole
	
cat << EOF > $GUACD_FILE
# Config
[server]

bind_host = 127.0.0.1
bind_port = 4822
 

EOF

cat << EOF > $GUACAMOLE_PROP_FILE
guacd-hostname: localhost
guacd-port: 4822
user-mapping: /etc/guacamole/user-mapping.xml
auth-provider: net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
EOF


echo "GUACAMOLE_HOME=/etc/guacamole" | sudo tee -a /etc/default/tomcat

ln -s /etc/guacamole /usr/share/tomcat/.guacamole

# Guacamole Client
wget https://downloads.apache.org/guacamole/1.5.4/binary/guacamole-1.5.4.war 
mv guacamole-1.5.4.war /etc/guacamole/guacamole.war
ln -s /etc/guacamole/guacamole.war /usr/share/tomcat/webapps/

}

function create_user_mapping_file()
{
echo "Create file $USER_MAPPING_FILE"

cat << EOF > $USER_MAPPING_FILE
<user-mapping>
  <!-- Created by $0 script -->


EOF


for item in "${!users_dict[@]}"
do
    arr_user=$item
    arr_pass=${users_dict[$item]}
    encrypt_pass $arr_pass
    arr_pass=$TMP_PASS
    echo "   <authorize" >> $USER_MAPPING_FILE
    echo "     username=\"$arr_user\"" >> $USER_MAPPING_FILE
    echo "     password=\"$arr_pass\"" >> $USER_MAPPING_FILE
    echo "     encoding=\"md5\">" >> $USER_MAPPING_FILE
    echo "" >> $USER_MAPPING_FILE

    for item in "${!servers_dict[@]}"
        do
        arr_conn=$item
        arr_ip=${servers_dict[$item]}
            echo "   <connection name=\"$arr_conn\">" >> $USER_MAPPING_FILE
            echo "     <protocol>ssh</protocol>" >> $USER_MAPPING_FILE
            echo "     <param name=\"hostname\">$arr_ip</param>" >> $USER_MAPPING_FILE
            echo "     <param name=\"port\">22</param>" >> $USER_MAPPING_FILE
            echo "   </connection>" >> $USER_MAPPING_FILE

            echo "" >> $USER_MAPPING_FILE
        done
    echo "   </authorize>" >> $USER_MAPPING_FILE
    echo "" >> $USER_MAPPING_FILE
done


cat << EOF >> $USER_MAPPING_FILE
 </user-mapping>
EOF
}

function restart_services()
{
	systemctl restart tomcat
	fail_ok "Restart tomcat"
	systemctl restart guacd
	fail_ok "Restart guacd"
	echo ""
}



function status()
{
	checkService tomcat
	checkService guacd
	check_file $USER_MAPPING_FILE
	check_file $GUACD_FILE
	check_file $GUACAMOLE_PROP_FILE
}



function encrypt_pass()
{
    PASS=$1
    TMP_PASS=`echo -n $PASS | openssl md5 | awk '{print $2}'`
}




command() {
case "$1" in
	install)
		install
		;;

	configure | reconfigure)
		create_user_mapping_file
		;;

	status)
		status
		;;

	restart)
		restart_services
		status
		;;
	*)
		echo "Usage: $0 { install | check | configure | add-resolv | restore-resolv | uninstall }"
		echo ""
		echo "    install - Install Pocket DNS"
		echo "    configure - Add users to guacamole config"
		echo "    status - Check status"
		echo "    restart - Restart systemctl services"
		echo ""
		exit 1
  esac
}

command "$1"


exit 0