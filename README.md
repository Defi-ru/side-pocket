# side-pocket
Small scripts help with infrastructure deployment

## pocket-dns.sh
Install & configure DNS

Supported OS: 
CentOS 7, CentOS 8 (configure selinux), CentOS 9
RedOS 7.3c, 7.3.x, 8.x
Alma Linux 8, Alma 9
Rocky 8, Rocky 9
Oracle Linux 7 (need manual install bind package) Oracle 8, Oracle 9
Fedora 37, Fedora 38

Usage: Run script & read docs
• Download script
• vi pocket-dns.sh - fill vars
• chmod +x pocket-dns.sh
• ./pocket-dns.sh install
• ./pocket-dns.sh check

## pocket-openvpn.sh
Install & configure OpenVPN

Supported OS: CentOS 7

Usage: Run script & read docs

### 1. When script ask server name, print "server"
### 2. On CentOS 7 set on "ip forwarding"
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

### 3.Firewalld (modern)
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service openvpn
firewall-cmd --add-masquerade
firewall-cmd --reload

### Deprecated (via iptables) don't forget save iptable (or lost settings after reboot server)
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE


# Release Notes
## pocket-dns.sh
v1.1.1
- refactoring code. Array replaced by dictionary
- add in "check" command nslookup test
- support new OS: Alma, Rocky, Oracle, new CentOS, Fedora

v1.0.0 base version