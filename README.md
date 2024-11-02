# side-pocket
Small scripts help with infrastructure deployment

Get
```
dnf install git -y
git clone https://github.com/Defi-ru/side-pocket.git
cd side-pocket
```

## pocket-dns.sh
Install & configure DNS  

Supported OS:  
CentOS 7, CentOS 8 (configure selinux), CentOS 9  
RedOS 7.3c, 7.3.x, 8.x  
Alma Linux 8, Alma 9  
Rocky 8, Rocky 9  
Oracle Linux 7 (need manual install bind package) Oracle 8, Oracle 9  
Fedora 37, Fedora 38  

### Usage: Run script & read docs
Prepaer DNS clients → Linux hosts must be referenced to our DNS server.  
Sometimes it is recommended to write it in /etc/resolv.conf, but this is not the right way. It will work only until reboot.  
The settings will depend on your OS, in RHEL-like/CentOS I recommend using `nmtui` utility.  

Firewall on RHEL-like (if used)  
```
firewall-cmd --permanent --add-protocol=53/udp
firewall-cmd --reload
```

Download script from GIT  

Fill vars (DNS server IP, servers name/ip)
```
vi pocket-dns.sh
```
Set script executeble  
```
chmod +x pocket-dns.sh  
```
Isntall bind/named  
```
./pocket-dns.sh install
```
Check DNS
```
./pocket-dns.sh check
```

## pocket-openvpn.sh
Install & configure OpenVPN  

Supported OS: CentOS 7, Red OS 7.3.4

### Usage
Fill vars (IP, ports)
```
vi pocket-openvpn.sh
```
Prepare script
```
chmod +x pocket-openvpn.sh
```

### 1. Install packages
```
./pocket-openvpn.sh install
```

When script ask server name, print:  
```
server
```

### 2. Bootsrap (create CA, DH, keys and certs)
```
./pocket-openvpn.sh bootstrap
```

### 3. Add user (user01 as example)
```
./pocket-openvpn.sh useradd user01
```
Get user dir /etc/openvpn/users/user01 & send it to user
Install "OpenVPN Connect" to user  
Add openvpn config file "user01.ovpn" to "OpenVPN Connect"  


### 4. On CentOS 7 set on "ip forwarding"
```
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

### 5.Firewalld (modern)
```
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service openvpn
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload
```

### Deprecated (via iptables) don't forget save iptable (or lost settings after reboot server)
```
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
```

# Release Notes
## pocket-dns.sh
v1.1.1  
- refactoring code. Array replaced by dictionary
- add in "check" command nslookup test
- support new OS: Alma, Rocky, Oracle, new CentOS, Fedora

v1.0.0  
- base version

## pocket-openvpn.sh
v0.8.2  
- Add Red OS 7.3.4 support
- Rework documentation

v0.7.6  
- Add CentOS 7 support