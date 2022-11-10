#!/bin/bash
cp /usr/share/zoneinfo/Asia/Manila /etc/localtime

MYIP=$(wget -qO- icanhazip.com);
genA=$(echo "$(pwgen 10 1)" | tr '[:upper:]' '[:lower:]')
genNS=$(echo "$(pwgen 5 1)" | tr '[:upper:]' '[:lower:]')
secretkey='server'
dnsresolverName="1.1.1.1"
dnsresolverType="udp"
dnsresolver="1.1.1.1:53"

dnsdomain=basicknowlege.com
dnszone=2b3cc8d36f3d84710278aef4325adf1b
dnsapi=c4873e05192b6e1529d72f081e6a0a90f0a2e
dnsemail=ericlaylay01022987@gmail.com

arecord="$genA.$dnsdomain"
nsrecord="$genNS.$dnsdomain"
hostname=$arecord
domain=$nsrecord

activeAPI='http://ouestvpn.store/api/authentication/active.php?key=FIRENET541'
inactiveAPI='http://ouestvpn.store/api/authentication/inactive.php?key=FIRENET541'
deletedAPI='http://ouestvpn.store/api/authentication/deleted.php?key=FIRENET541'

init_install (){
clear
apt update
apt upgrade -y
{
apt install -y git screen whois stunnel4 dropbear wget
apt install -y pwgen python php jq curl
apt install -y fail2ban sudo gnutls-bin
apt install -y mlocate dh-make libaudit-dev build-essential
apt install -y dos2unix debconf-utils
sudo shutdown -r +10
} &>/dev/null
}

init_start (){
clear
curl -4skL "http://firenetvpn.net/files/banner" -o /etc/banner

curl -X POST "https://api.cloudflare.com/client/v4/zones/$dnszone/dns_records" -H "X-Auth-Email: $dnsemail" -H "X-Auth-Key: $dnsapi" -H "Content-Type: application/json" --data '{"type":"NS","name":"'"$(echo $nsrecord)"'","content":"'"$(echo $arecord)"'","ttl":1,"priority":0,"proxied":false}' &>/dev/null
}

install_firewall (){
{
sudo iptables -I INPUT -p udp --dport 5300 -j ACCEPT &>/dev/null;
sudo iptables -t nat -I PREROUTING -i $(ip route get 8.8.8.8 | awk '/dev/ {f=NR} f&&NR-1==f' RS=" ") -p udp --dport 53 -j REDIRECT --to-ports 5300 &>/dev/null;
sudo ip6tables -I INPUT -p udp --dport 5300 -j ACCEPT &>/dev/null;
sudo ip6tables -t nat -I PREROUTING -i $(ip route get 8.8.8.8 | awk '/dev/ {f=NR} f&&NR-1==f' RS=" ") -p udp --dport 53 -j REDIRECT --to-ports 5300 &>/dev/null;
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt -y install iptables-persistent
}&>/dev/null
}

install_sudo (){
echo "Initializing..."
{
echo "/bin/false" >> /etc/shells
rm /etc/ssh/sshd_config
if [[ $serverVersion == "18.04" ]]
then
wget 'http://firenetvpn.net/files/slowdns/UbuntuSSH18' -O /etc/ssh/sshd_config
elif [[ $serverVersion == "20.04" ]]
then
wget 'http://firenetvpn.net/files/slowdns/UbuntuSSH20' -O /etc/ssh/sshd_config
else
# Debian Default
wget 'http://firenetvpn.net/files/slowdns/Debian' -O /etc/ssh/sshd_config
fi
service sshd restart
}&>/dev/null
}

install_security (){
echo "Installing fail2ban..."
    {
        systemctl fail2ban enable
        cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
        sed -i 's/bantime  = 600/bantime  = 3600/g' /etc/fail2ban/jail.local
        sed -i 's/maxretry = 6/maxretry = 20/g' /etc/fail2ban/jail.local
        service fail2ban start
    }&>/dev/null
}

install_stunnel_dropbear (){
echo "Installing stunnel and dropbear..."
{
cd /etc/stunnel/
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 -sha256 -subj '/CN=FirenetPH/O=FirenetDev/C=PH' -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem
echo "pid = /tmp/stunnel.pid
debug = 0
output = /tmp/stunnel.log
[ssh]
connect = 22
accept = 445
cert = /etc/stunnel/stunnel.pem

[dropbear]
connect = 701
accept = 444
cert = /etc/stunnel/stunnel.pem" >> stunnel.conf
cd /etc/default && rm stunnel4 && rm dropbear
echo 'ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/banner"
PPP_RESTART=0
RLIMITS=""' >> stunnel4 
echo 'NO_START=0
DROPBEAR_PORT=701
DROPBEAR_EXTRA_ARGS=
DROPBEAR_BANNER="/etc/banner"
DROPBEAR_RECEIVE_WINDOW=65536' >> dropbear
chmod 755 stunnel4 && chmod 755 dropbear
sudo service stunnel4 restart
sudo service dropbear restart
} &>/dev/null
}

install_squid (){
echo "Installing squid..."
echo "This may take for a while, just wait..."
{
if [[ $serverDistro == "ubuntu" ]]
then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list_backup
    echo "deb http://us.archive.ubuntu.com/ubuntu/ trusty main universe" | sudo tee --append /etc/apt/sources.list.d/trusty_sources.list > /dev/null
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 40976EAF437D05B5
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32    
    sudo apt update
    sudo apt install -y squid3=3.3.8-1ubuntu6 squid=3.3.8-1ubuntu6 squid3-common=3.3.8-1ubuntu6
    cd /etc/init.d/; curl -O -J -L 'http://firenetvpn.net/files/slowdns/squid3';
    dos2unix /etc/init.d/squid3
    sudo chmod +x /etc/init.d/squid3
    sudo update-rc.d squid3 defaults
    sudo update-rc.d squid3 enable
    cd /etc/squid3/
    rm squid.conf
    echo "acl SSH dst `curl -s https://api.ipify.org`" >> squid.conf
    echo 'acl SSL_ports port 445
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 445
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT
http_access allow SSH
http_access deny manager
http_access deny all
http_port 8080
http_port 8181
coredump_dir /var/spool/squid3
refresh_pattern ^ftp: 1440 20% 10080
refresh_pattern ^gopher: 1440 0% 1440
refresh_pattern -i (/cgi-bin/|\?) 0 0% 0
refresh_pattern . 0 20% 4320
visible_hostname Firenet-Proxy
error_directory /usr/share/squid3/errors/English' >> squid.conf
    cd /usr/share/squid3/errors/English
    rm ERR_INVALID_URL
    echo '<!--FirenetDev--><!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>SECURE PROXY</title><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="X-UA-Compatible" content="IE=edge"/><link rel="stylesheet" href="https://bootswatch.com/4/slate/bootstrap.min.css" media="screen"><link href="https://fonts.googleapis.com/css?family=Press+Start+2P" rel="stylesheet"><style>body{font-family: "Press Start 2P", cursive;}.fn-color{color: #ffff; background-image: -webkit-linear-gradient(92deg, #f35626, #feab3a); -webkit-background-clip: text; -webkit-text-fill-color: transparent; -webkit-animation: hue 5s infinite linear;}@-webkit-keyframes hue{from{-webkit-filter: hue-rotate(0deg);}to{-webkit-filter: hue-rotate(-360deg);}}</style></head><body><div class="container" style="padding-top: 50px"><div class="jumbotron"><h1 class="display-3 text-center fn-color">SECURE PROXY</h1><h4 class="text-center text-danger">SERVER</h4><p class="text-center">馃槏 %w 馃槏</p></div></div></body></html>' >> ERR_INVALID_URL
    chmod 755 *
    service squid3 start
else
    echo "deb http://ftp.debian.org/debian/ jessie main contrib non-free
    deb-src http://ftp.debian.org/debian/ jessie main contrib non-free
    deb http://security.debian.org/ jessie/updates main contrib
    deb-src http://security.debian.org/ jessie/updates main contrib
    deb http://ftp.debian.org/debian/ jessie-updates main contrib non-free
    deb-src http://ftp.debian.org/debian/ jessie-updates main contrib non-free" >> /etc/apt/sources.list
    apt update
    apt install -y gcc-4.9 g++-4.9
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 10
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 10
    update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
    update-alternatives --set cc /usr/bin/gcc
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30
    update-alternatives --set c++ /usr/bin/g++
    cd /usr/src
    wget http://www.squid-cache.org/Versions/v3/3.1/squid-3.1.23.tar.gz
    tar zxvf squid-3.1.23.tar.gz
    cd squid-3.1.23
    ./configure --prefix=/usr \
      --localstatedir=/var/squid \
      --libexecdir=${prefix}/lib/squid \
      --srcdir=. \
      --datadir=${prefix}/share/squid \
      --sysconfdir=/etc/squid \
      --with-default-user=proxy \
      --with-logdir=/var/log/squid \
      --with-pidfile=/var/run/squid.pid
    make -j$(nproc)
    make install
    wget --no-check-certificate -O /etc/init.d/squid http://firenetvpn.net/files/slowdns/squid.sh
    chmod +x /etc/init.d/squid
    update-rc.d squid defaults
    chown -cR proxy /var/log/squid
    squid -z
    cd /etc/squid/
    rm squid.conf
    echo "acl Firenet dst `curl -s https://api.ipify.org`" >> squid.conf
    echo 'http_port 8080
http_port 8181
visible_hostname Proxy
acl PURGE method PURGE
acl HEAD method HEAD
acl POST method POST
acl GET method GET
acl CONNECT method CONNECT
http_access allow Firenet
http_reply_access allow all
http_access deny all
icp_access allow all
always_direct allow all
visible_hostname Firenet-Proxy
error_directory /share/squid/errors/templates' >> squid.conf
    cd /share/squid/errors/templates
    rm ERR_INVALID_URL
    echo '<!--FirenetDev--><!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>SECURE PROXY</title><meta name="viewport" content="width=device-width, initial-scale=1"><meta http-equiv="X-UA-Compatible" content="IE=edge"/><link rel="stylesheet" href="https://bootswatch.com/4/slate/bootstrap.min.css" media="screen"><link href="https://fonts.googleapis.com/css?family=Press+Start+2P" rel="stylesheet"><style>body{font-family: "Press Start 2P", cursive;}.fn-color{color: #ffff; background-image: -webkit-linear-gradient(92deg, #f35626, #feab3a); -webkit-background-clip: text; -webkit-text-fill-color: transparent; -webkit-animation: hue 5s infinite linear;}@-webkit-keyframes hue{from{-webkit-filter: hue-rotate(0deg);}to{-webkit-filter: hue-rotate(-360deg);}}</style></head><body><div class="container" style="padding-top: 50px"><div class="jumbotron"><h1 class="display-3 text-center fn-color">SECURE PROXY</h1><h4 class="text-center text-danger">SERVER</h4><p class="text-center">馃槏 %w 馃槏</p></div></div></body></html>' >> ERR_INVALID_URL
    chmod 755 *
    /etc/init.d/squid start
fi
} &>/dev/null
}

ConfigAuthentication(){
echo -e "[\e[32mInfo\e[0m] Configuring Authentication"

curl -4skL "$activeAPI" -o /etc/active.sh
curl -4skL "$inactiveAPI" -o /etc/inactive.sh
curl -4skL "$deletedAPI" -o /etc/deleted.sh

cat <<'authEOF'> /etc/fetch_user.bash
#!/bin/bash
curl -4skL "$activeAPI" -o /etc/active.sh
curl -4skL "$inactiveAPI" -o /etc/inactive.sh
curl -4skL "$deletedAPI" -o /etc/deleted.sh
authEOF

chmod +x /etc/fetch_user.bash
chmod +x /etc/active.sh
chmod +x /etc/inactive.sh
chmod +x /etc/deleted.sh

echo -e "*/5 *\t* * *\troot\tbash /etc/fetch_user.bash" >> /etc/cron.d/authentication
echo -e "*/5 *\t* * *\troot\tbash /etc/active.sh" >> /etc/cron.d/authentication
echo -e "*/5 *\t* * *\troot\tbash /etc/inactive.sh" >> /etc/cron.d/authentication
echo -e "*/5 *\t* * *\troot\tbash /etc/deleted.sh" >> /etc/cron.d/authentication
}

install_slowdns (){
echo "Installing dns..."
{
# Install Go language
cd /usr/local
wget https://golang.org/dl/go1.16.2.linux-amd64.tar.gz
tar xvf go1.16.2.linux-amd64.tar.gz
export GOROOT=/usr/local/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Config Ssh
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config

# SET DNSTT
export DNSDIR=/etc/.dnsquest
export DNSCONFIG=/root/.dns
mkdir -m 777 $DNSDIR
mkdir -m 777 $DNSCONFIG
echo "password `mkpasswd @@F1r3n3t`" >> $DNSDIR/.sckey
cd $DNSDIR
git clone https://www.bamsoftware.com/git/dnstt.git

# BUILD DNSTT SERVER
cd $DNSDIR/dnstt/dnstt-server
go build
./dnstt-server -gen-key -privkey-file server.key -pubkey-file server.pub
cp server.key server.pub $DNSCONFIG
cp dnstt-server $DNSDIR

# BUILD DNSTT CLIENT
cd $DNSDIR/dnstt/dnstt-client
go build
cp dnstt-client $DNSDIR

#Source
echo "domain=$domain
privkey=`cat /root/.dns/server.key`
pubkey=`cat /root/.dns/server.pub`
os=$serverDistro
dnsresolvertype=$dnsresolverType
dnsresolver=$dnsresolver" >> $DNSCONFIG/config

#Get Socks Proxy
apt remove apache2 -y
wget http://firenetvpn.net/files/slowdns/socks-ws-ssh.py -O $DNSDIR/socks-ssh.py
wget http://firenetvpn.net/files/slowdns/socks-ws-ssl.py -O $DNSDIR/socks-ssl.py
wget http://firenetvpn.net/files/slowdns/socks-ssh.py -O $DNSDIR/socks.py
dos2unix $DNSDIR/socks-ssh.py
dos2unix $DNSDIR/socks-ssl.py
dos2unix $DNSDIR/socks.py
chmod +x $DNSDIR/socks-ssh.py
chmod +x $DNSDIR/socks-ssl.py
chmod +x $DNSDIR/socks.py

#Get Delete Expired script
wget http://firenetvpn.net/files/slowdns/delete_expired -O /home/delete_expired
chmod +x /home/delete_expired
} &>/dev/null
}

rebootserver () {
echo "Starting..."
{
# Daily reboot time of our machine
# For cron commands, visit https://crontab.guru
echo -e "0 4\t* * *\troot\treboot" > /etc/cron.d/b_reboot_job

# START ON BOOT
cd ~
wget http://firenetvpn.net/files/slowdns/services -O .services;chmod +x .services;
sudo crontab -l | { echo '@reboot /root/.services'; } | crontab -
#Reboot
mkdir -m 777 /root/web
echo "Why do astronauts use Linux?<br>
Because you can't open Windows in space... " >> /root/web/index.php
echo "Hi! this is your server information, Happy Surfing!

IP : $serverIp
SSH : 22
SSH via DNS : 2222
SSH SSL : 445
DROPBEAR : 701
DROPBEAR SSL : 444
SQUID : 8080, 8181
HTTP/SOCKS : 8000
Websocket SSH: 80
Websocket SSL: 443
Websocket Hostname: $hostname

-----------------------
DNS URL : $domain
DNS RESOLVER : $dnsresolverName
DNS PUBLIC KEY : $(cat /root/.dns/server.pub)
-----------------------

FB Page : https://facebook.com/firenetphilippines

For issues or suggestions please open an issue on github.

" >> /root/web/$secretkey.txt
rm -f ~/.installer
rm -f /root/.bash_history && history -c && echo '' > /var/log/syslog
sleep 20
reboot  
}
}

serverDistro=`awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }'`
serverVersion=`awk '/^VERSION_ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }'`
serverIp=`ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'`

init_install
init_start
install_firewall
install_sudo
install_security
install_stunnel_dropbear
install_squid
install_slowdns
