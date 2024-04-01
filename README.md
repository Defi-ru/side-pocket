# side-pocket
Small scripts help with infrastructure deployment

## pocket-dns.sh
Install & configure DNS
Supported OS: CentOS 7
Usage: Run script & read docs


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
