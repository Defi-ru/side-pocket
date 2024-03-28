#!/bin/bash
# Script Name: pocket-dns.sh
# v1.0.0
# Tested on: CentOS 7, RedOS 7.2, RedOS 7.3
# Requirements: ping by ip SUCCESS, ssh SUCCESS
# 
# Install, configure DNS. Can replace resolv.conf on remote servers.
# You can also restore the old resolv.conf.
# There is an option to delete the Pocket DNS by cleaning up after yourself.

# === SETTINGS
DOMAIN=example.com
DNS_IP=auto # auto / <dns_ip_adress>

# Server Name without domain:
SERVER_NAME[0]="srv-hdp01"; SERVER_IP[0]="192.168.30.141"
SERVER_NAME[1]="srv-hdp02"; SERVER_IP[1]="192.168.30.142"
SERVER_NAME[2]="srv-hdp03"; SERVER_IP[2]="192.168.30.143"


SERIAL_NUMBER=20230427

NAMED_CONF=/etc/named.conf
MATER_ZONE=/var/named/master/$DOMAIN
BIND_BIN=/usr/sbin/named-checkconf


# === SCRIPT
# Set vars
if [ $DNS_IP == "auto" ]; then
	DNS_IP=`hostname -I`
	echo "DNS_IP is set to $DNS_IP"
fi

# Functions
function fail_ok()
{
    if [ $? -eq 0 ];then
        echo -ne "$GREEN_COLOR [OK] $CLEAR_COLOR $1"
        echo
    else
        echo -ne "$RED_COLOR [fail] $CLEAR_COLOR $1"
        echo
    fi
}

function reverse_ip()
{
    IFS='.'
    read -a strarr <<< "$1"
    echo "${strarr[3]}.${strarr[2]}.${strarr[1]}.${strarr[0]}"
    IFS=''
}

function cut_ip()
{
    IFS='.'
    read -a strarr <<< "$1"
    case "$2" in


        "1")
         echo "${strarr[0]}"
         ;;

        "2")
         echo "${strarr[0]}.${strarr[1]}"
         ;;

        "3")
         echo "${strarr[0]}.${strarr[1]}.${strarr[2]}"
         ;;

    esac
    IFS=''
}


# 1. Install
function install_dns
{
	yum install bind -y
	systemctl enable named
}

function configure_dns
{
	# 2. modify named.conf
	REVERSE_IP_ZONE=`cut_ip $DNS_IP 3`
	REVERSE_IP_ZONE=`reverse_ip $REVERSE_IP_ZONE`
	REVERSE_IP_ZONE=`echo $REVERSE_IP_ZONE | cut -c2-`
	REVERSE_ZONE=/var/named/master/$REVERSE_IP_ZONE.db


cat << EOF > $NAMED_CONF
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a any DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

options {
        listen-on port 53 { 127.0.0.1; localhost; $DNS_IP; };
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { any; };

        /*
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable
           recursion.
         - If your recursive DNS server has a public IP address, you MUST enable access
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface
        */
        recursion yes;

        dnssec-validation yes;

        /* Path to ISC DLV key */
        bindkeys-file "/etc/named.root.key";

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
        type hint;
        file "named.ca";
};

zone "$DOMAIN" IN {
        type master;
        file "master/$DOMAIN";
        allow-transfer { $DNS_IP; };
        allow-update { none; };
};

zone "$REVERSE_IP_ZONE.in-addr.arpa" IN {
        type master;
        file "master/$REVERSE_IP_ZONE.db";
        allow-update { none; };
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

EOF


# 3. Add Zones
mkdir -p /var/named/master
cat << EOF > $MATER_ZONE
\$TTL 14400

$DOMAIN.     IN      SOA     ns1.$DOMAIN. admin.$DOMAIN. (
        $SERIAL_NUMBER        ; Serial
        10800           ; Refresh
        3600            ; Retry
        604800          ; Expire
        604800          ; Negative Cache TTL
)

                IN      NS      ns1.$DOMAIN.
                IN      NS      ns2.$DOMAIN.

                IN      MX 10   mx.$DOMAIN.
                IN      MX 20   mx2.$DOMAIN.

@               IN      A       $DNS_IP
localhost       IN      A       127.0.0.1
ns1             IN      A       $DNS_IP
ns2             IN      A       192.168.1.3

www             IN      CNAME   $DOMAIN.


EOF

cat << EOF > $REVERSE_ZONE
\$TTL 14400

$REVERSE_IP_ZONE.in-addr.arpa. IN SOA ns1.$DOMAIN. admin.$DOMAIN. (
        $SERIAL_NUMBER        ; Serial
        10800           ; Refresh
        3600            ; Retry
        604800          ; Expire
        604800          ; Negative Cache TTL
)

							IN      NS      ns1.$DOMAIN.

EOF

# ======================================= A Records
i=0
for item in ${SERVER_NAME[*]}
    do
      echo "${SERVER_NAME[$i]}	IN	A	${SERVER_IP[$i]}" >> $MATER_ZONE
      let "i=i+1"
    done

# ======================================= PTR Records
i=0
for item in ${SERVER_NAME[*]}
    do
	  rev_ip=`reverse_ip ${SERVER_IP[i]}`
	  echo "$rev_ip.in-addr.arpa.        IN      PTR     ${SERVER_NAME[$i]}.$DOMAIN". >> $REVERSE_ZONE
      let "i=i+1"
    done

systemctl restart named
}

function check_dns
{
	$BIND_BIN -z $NAMED_CONF
}


function add_resolv_conf
{
	COMMAND1="search $DOMAIN"
	COMMAND2="nameserver $DNS_IP"
	
    i=0
    for item in ${SERVER_IP[*]}
        do
			if [ ! -f resolv_conf.saved ]; then
				scp ${SERVER_IP[i]}:/etc/resolv.conf resolv_conf.saved
			fi
            ssh -o BatchMode=yes -o "StrictHostKeyChecking no" ${SERVER_IP[i]} -C 'echo "# Generated by pocket-dns.sh script" > /etc/resolv.conf'
            ssh -o BatchMode=yes -o "StrictHostKeyChecking no" ${SERVER_IP[i]} -C "echo $COMMAND1 >> /etc/resolv.conf"
            ssh -o BatchMode=yes -o "StrictHostKeyChecking no" ${SERVER_IP[i]} -C "echo $COMMAND2 >> /etc/resolv.conf"
            fail_ok "Add string to $item"
            let "i=i+1"
        done
}

function restore_resolv_conf
{
	i=0
    for item in ${SERVER_IP[*]}
        do
			if [ -f resolv_conf.saved ]; then
				scp resolv_conf.saved ${SERVER_IP[i]}:/etc/resolv.conf
			fi
            fail_ok "Add string to $item"
            let "i=i+1"
        done
}

function uninstall_dns
{
	systemctl stop named
	systemctl disable named
	yum remove bind -y
	rm -rf /var/named
	rm -f /etc/named.conf.rpmnew
	rm -f /etc/named.conf.rpmsave
	rm -f resolv_conf.saved
}

command() {
  case "$1" in
  
    install)
      install_dns
      configure_dns
      ;;

    configure | reconfigure)
      configure_dns
      ;;
	  
    check)
      check_dns
      ;;
	  
    add-resolv)
      add_resolv_conf
      ;;

    restore-resolv)
      restore_resolv_conf
      ;;
	  
	uninstall)
	  restore_resolv_conf
      uninstall_dns
      ;;

    *)
		echo "Usage: $0 {install | check | configure | add-resolv | restore-resolv | uninstall}"
		echo "    install - Install Pocket DNS"
		echo "    check - Check bind (DNS) main config"
		echo "    configure - Reconfigure DNS"
		echo "    add_resolv - Save original files (resolv.conf.saved) from remote servers & change resolv.conf on remote servers"
		echo "    restore_resolv - Restore original resolv.conf (from resolv.conf.saved)"
		echo "    uninstall - Uninstall DNS & restore resolv.conf on remote servers, lists on SERVER_IP array in this script"
		exit 1
  esac
}

command "$1"


exit 0

# /usr/sbin/named-checkconf -z /etc/named.conf

# On Clients:
# cat /etc/resolv.conf
# search $DOMAIN
# namedserver <ip>