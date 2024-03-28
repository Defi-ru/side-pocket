#!/bin/bash
# Version: 0.7.4
# Script Name: pocket-openvpn.sh
# OpenVPN certificate/users control
# Run near easyrsa file

# === VARS
OPENVPN_SERVER_IP=192.168.130.22
OPEN_VPN_PORT=1194

OPEN_VPN_DIR=/etc/openvpn
USERS_DIR=$OPEN_VPN_DIR/users
OPEN_VPN_SERVER_CONF=$OPEN_VPN_DIR/server.conf

EASY_RSA_ARCHIVE=https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz
EASY_RSA_DOWNLOAD_DIR=$OPEN_VPN_DIR

EASY_RSA_VER=`echo $EASY_RSA_ARCHIVE | grep -oP '\d+\.\d+\.\d+' | head -1`
EASY_RSA_TAR=`basename $EASY_RSA_ARCHIVE`
EASY_RSA_DIR_NAME=`echo $EASY_RSA_TAR | sed 's/\.tgz$//'`

EASY_RSA_DIR=$OPEN_VPN_DIR/easyrsa3
EASY_RSA=$EASY_RSA_DIR/easyrsa
EASY_RSA_VARS=$OPEN_VPN_DIR/easyrsa3/vars

TA_KEY=$EASY_RSA_DIR/ta.key
CA_KEY=$EASY_RSA_DIR/pki/private/ca.key
CA_CRT=$EASY_RSA_DIR/pki/ca.crt
DH=$EASY_RSA_DIR/pki/dh.pem
SERVER_KEY=$EASY_RSA_DIR/pki/private/server.key
SERVER_CRT=$EASY_RSA_DIR/pki/issued/server.crt

CLIENT_KEY=$EASY_RSA_DIR/pki/private
CLIENT_CRT=$EASY_RSA_DIR/pki/issued




# ==== COLOR VARS
CLEAR_COLOR="\033[0m"
RED_COLOR="\033[31m"
GREEN_COLOR="\033[32m"
PURPLE_COLOR='\033[0;35m'
BLUE_COLOR='\033[0;34m'

# === SCRIPT
# Without this thing don't work arguments in functions
OVPN_USER=$2

PWD=`pwd`
# === SYSTEM FUNCTIONS
function fail_ok()
{
    if [ $? -eq 0 ];then
        echo -ne "[$GREEN_COLOR OK $CLEAR_COLOR] $1"
        echo
    else
        echo -ne "[$RED_COLOR fail $CLEAR_COLOR] $1"
        echo
    fi
}

function check_files()
{
    echo -e "$PURPLE_COLOR Check files $CLEAR_COLOR"

    if [ ! -f $TA_KEY ]; then
        echo -e "$RED_COLOR Error! TA_KEY file $TA_KEY not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check TA_KEY"

    if [ ! -f $CA_KEY ]; then
        echo -e "$RED_COLOR Error! CA_KEY file $CA_KEY not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check CA_KEY"

    if [ ! -f $CA_CRT ]; then
        echo -e "$RED_COLOR Error! CA_CRT file $CA_CRT not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check CA_CRT"

    if [ ! -f $DH ]; then
        echo -e "$RED_COLOR Error! DH file $DH not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check DH"

    if [ ! -f $SERVER_KEY ]; then
        echo -e "$RED_COLOR Error! SERVER_KEY file $SERVER_KEY not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check SERVER_KEY"

    if [ ! -f $SERVER_CRT ]; then
        echo -e "$RED_COLOR Error! SERVER_CRT file $SERVER_CRT not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check SERVER_CRT"

}

# === INSTALL FUNCTIONS
function install_server()
{
    # OpenVPN
    echo -e "$PURPLE_COLOR Install OpenVPN $CLEAR_COLOR"
    yum install epel-release -y #> /dev/null 2>&1
    fail_ok "Install epel-release"

    #yum update -y #> /dev/null 2>&1
    #fail_ok "Update packages"

    yum install openvpn -y #> /dev/null 2>&1
    fail_ok "Update packages"

    # EasyRSA
    #curl -L $EASY_RSA_ARCHIVE -o $EASY_RSA_DOWNLOAD_DIR/$EASY_RSA_TAR
    #fail_ok "Download EasyRSA"

    cd $OPEN_VPN_DIR
    tar xvf $EASY_RSA_TAR
    fail_ok "Untar EasyRSA"

    ln -s $OPEN_VPN_DIR/$EASY_RSA_DIR_NAME $EASY_RSA_DIR
    fail_ok "Create symlink"

    cd $PWD
    # broke symlink
    #rm $OPEN_VPN_DIR/$EASY_RSA_TAR
    #fail_ok "Delete archive EasyRSA"
}

# === BOOTSTRAP FUNCTIONS
function check_easyrsa_path()
{
    echo -e "$PURPLE_COLOR Check path $CLEAR_COLOR"
    EASY_RSA=empty
    if [ -f /etc/openvpn/easy_rsa/easyrsa3/easyrsa ]; then
        EASY_RSA=/etc/openvpn/easy_rsa/easyrsa3/easyrsa
        fail_ok "Easy RSA path is: /etc/openvpn/easy_rsa/easyrsa3/easyrsa"
    fi

    if [ -f /etc/openvpn/easy_rsa/easyrsa ]; then
        EASY_RSA=/etc/openvpn/easy_rsa/easyrsa
        fail_ok "Easy RSA path is: /etc/openvpn/easy_rsa/easyrsa"
    fi

    if [ -f /etc/openvpn/easyrsa3/easyrsa ]; then
        EASY_RSA=/etc/openvpn/easyrsa3/easyrsa
        fail_ok "Easy RSA path is: /etc/openvpn/easyrsa3/easyrsa"
    fi

    if [[ "$EASY_RSA" == "empty" ]]; then
        echo -e "$RED_COLOR Error! Can't find path easy rsa... $CLEAR_COLOR"
        exit 1
    fi

}

function template_vars()
{
cat << EOF > $EASY_RSA_VARS
if [ -z "$EASYRSA_CALLER" ]; then
        echo "You appear to be sourcing an Easy-RSA *vars* file. This is" >&2
        echo "no longer necessary and is disallowed. See the section called" >&2
        echo "*How to use this file* near the top comments for more details." >&2
        return 1
fi

set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "California"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "Copyleft Certificate Co"
set_var EASYRSA_REQ_EMAIL      "me@example.net"
set_var EASYRSA_REQ_OU         "My Organizational Unit"

export KEY_NAME="server"
export KEY_CN=openvpn.yourdomain.com
EOF
}

function bootstrap_openvpn()
{
    echo -e "$PURPLE_COLOR Bootstrap OpenVPN Server $CLEAR_COLOR"

    mkdir -p /var/log/openvpn
    fail_ok "Create log dir (/var/log/openvpn)"

    touch /var/log/openvpn-status.log
    fail_ok "Create openvpn-status.log"

    touch /var/log/openvpn/openvpn.log
    fail_ok "Create openvpn.log"


    cd $EASY_RSA_DIR
    $EASY_RSA clean-all
    fail_ok "Easy RSA clean-all"

    $EASY_RSA build-ca nopass
    fail_ok "Easy RSA build-ca nopass"

    $EASY_RSA gen-dh
    fail_ok "Easy RSA gen-dh"

    $EASY_RSA build-server-full server nopass
    fail_ok "Easy RSA build-server-full server nopass"
    cd $PWD

    openvpn --genkey --secret ta.key
    fail_ok "Generate ta.key"
}

function tepmlate_server_config()
{
cat << EOF > $OPEN_VPN_SERVER_CONF
# Basic settings
port $OPEN_VPN_PORT
proto udp
dev tun
# Configs
ca $CA_CRT
cert $EASY_RSA_DIR/pki/issued/server.crt
key $EASY_RSA_DIR/pki/private/server.key  # This file should be kept secret
dh $DH
tls-auth $TA_KEY 0
#
cipher AES-256-GCM
ifconfig-pool-persist ipp.txt
client-to-client
#client-config-dir /etc/openvpn/ccd
keepalive 10 120
max-clients 32
persist-key
persist-tun
verb 4
mute 20
daemon
mode server
tls-server
comp-lzo
tun-mtu 1500
mssfix 1620
# Logs
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log

# Network settings
server 10.0.0.0 255.255.255.0
topology subnet
push "dhcp-option DNS 8.8.8.8"
#push "route 192.168.77.0 255.255.255.0"
#push "redirect-gateway def1"
EOF
fail_ok "Template OpenVPN Server Config"
}

function restart_server()
{
	systemctl restart openvpn@server
}
# === USER FUNCTIONS
function add_user()
{
    if [ -z "$OVPN_USER" ];then
        echo -e "$RED_COLOR Error! Command 'user' must include argumnet 'user name'... $CLEAR_COLOR"
        exit 2
    fi
    echo -e "$PURPLE_COLOR Create user $CLEAR_COLOR"
    cd $EASY_RSA_DIR
    $EASY_RSA build-client-full $OVPN_USER nopass
    cd $PWD
	
	echo "$OVPN_USER" >> $USERS_DIR/ovpn_users.txt
}

function copy_user()
{
    echo -e "$PURPLE_COLOR Move user $CLEAR_COLOR"

    # Check client files
    if [ ! -f $CLIENT_KEY/$OVPN_USER.key ]; then
        echo -e "$RED_COLOR Error! CLIENT_KEY file $CLIENT_KEY/$OVPN_USER.key not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check CLIENT_KEY"

    if [ ! -f $CLIENT_CRT/$OVPN_USER.crt ]; then
        echo -e "$RED_COLOR Error! CLIENT_CRT file $CLIENT_CRT/$OVPN_USER.crt not exist... $CLEAR_COLOR"
    fi
    fail_ok "Check CLIENT_CRT"


    mkdir -p $USERS_DIR
    fail_ok "Create users dir: $USERS_DIR"

    mkdir -p $USERS_DIR/$OVPN_USER
    fail_ok "Create dir for user: $OVPN_USER"


    cp $TA_KEY $USERS_DIR/$OVPN_USER
    fail_ok "Copy TA_KEY for user: $OVPN_USER"

    cp $CA_CRT $USERS_DIR/$OVPN_USER
    fail_ok "Copy CA_CRT for user: $OVPN_USER"

    cp $CLIENT_KEY/$OVPN_USER.key $USERS_DIR/$OVPN_USER/
    fail_ok "Copy CLIENT_KEY for user: $OVPN_USER"

    cp $CLIENT_CRT/$OVPN_USER.crt $USERS_DIR/$OVPN_USER/
    fail_ok "Copy CLIENT_CRT for user: $OVPN_USER"

}

function template_client_ovpn()
{
cat << EOF > $USERS_DIR/$OVPN_USER/$OVPN_USER.ovpn
$OVPN_USER
cert $OVPN_USER .crt
key $OVPN_USER.key
ca ca.crt
tls-client
tls-auth ta.key 1
resolv-retry infinite
nobind
remote $OPENVPN_SERVER_IP $OPEN_VPN_PORT
proto udp
dev tun
comp-lzo
float
keepalive 10 120
persist-key
persist-tun
tun-mtu 1500
mssfix 1620
cipher AES-256-GCM
verb 0
EOF
fail_ok "Template client $OVPN_USER.ovpn config"
}

function reconfigure_client_ovpn()
{
	TMP_USER=$OVPN_USER
	for user in $(cat $USERS_DIR/ovpn_users.txt)
    do
		OVPN_USER=$user
        template_client_ovpn
    done
	# Return first OVPN_USER
	OVPN_USER=$TMP_USER
}

command()
{
    case "$1" in
    install)
        install_server
        ;;
    bootstrap)
        check_easyrsa_path
        template_vars
        bootstrap_openvpn
        tepmlate_server_config
		restart_server
        ;;
    user)
        check_easyrsa_path
        add_user
        check_files
        copy_user
        template_client_ovpn
        ;;
    configure)
        tepmlate_server_config
		reconfigure_client_ovpn
		restart_server
        ;;
    check)
        check_easyrsa_path
        check_files
        ;;
    *)
        echo "Usage: $0 { install | user | configure }"
        echo ""
        echo "    install - install OpenVPN Server"
        echo "    bootstrap - Destroy OpenVPN server (clean certs) & install new"
        echo "    user <user_name> - create user"
        echo "    configure - reconfigure OpenVPN server"
        echo "    check - check configs files for exsists"
        exit 1
    esac
}

command "$1"