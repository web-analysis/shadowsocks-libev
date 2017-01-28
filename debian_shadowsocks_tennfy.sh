#! /bin/bash
#===============================================================================================
#   System Required:  Debian or Ubuntu (32bit/64bit)
#   Description:  Install Shadowsocks(libev) for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================

clear
echo "#############################################################"
echo "# Install Shadowsocks(libev) for Debian or Ubuntu (32bit/64bit)"
echo "# Intro: http://www.tennfy.com"
echo "#"
echo "# Author: tennfy <admin@tennfy.com>"
echo "#"
echo "#############################################################"
echo ""

function check_sanity {
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		die "Distribution is not supported"
	fi
}

function die {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

############################### install function##################################
function install_shadowsocks_tennfy(){
cd $HOME

# install
apt-get update
apt-get install -y --force-yes build-essential autoconf libtool libssl-dev curl asciidoc xmlto libpcre3 libpcre3-dev

# install libsodium for chacha20
wget https://github.com/jedisct1/libsodium/releases/download/1.0.11/libsodium-1.0.11.tar.gz
tar -xf libsodium-1.0.11.tar.gz && cd libsodium-1.0.11
./configure && make && make install
ldconfig

#download latest release version of shadowsocks-libev
LatestRlsVer=$(curl -s "https://api.github.com/repos/shadowsocks/shadowsocks-libev/releases/latest" | grep "tag_name" | cut -d\" -f4 | cut -d'v' -f2)
wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/archive/v${LatestRlsVer}.tar.gz
tar zxvf v${LatestRlsVer}.tar.gz 
mv shadowsocks-libev-${LatestRlsVer} shadowsocks-libev

#compile install
cd shadowsocks-libev
./configure --prefix=/usr
make && make install
mkdir -p /etc/shadowsocks-libev
cp ./debian/shadowsocks-libev.init /etc/init.d/shadowsocks-libev
cp ./debian/shadowsocks-libev.default /etc/default/shadowsocks-libev
chmod +x /etc/init.d/shadowsocks-libev

# Get IP address(Default No.1)
IP=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
if [ -z $IP ]; then
   IP=`curl -s ifconfig.me/ip`
fi

#config setting
echo "#############################################################"
echo "#"
echo "# Please input your shadowsocks server_port and password"
echo "#"
echo "#############################################################"
echo ""
echo "input server_port(443 is suggested):"
read serverport
echo "input password:"
read shadowsockspwd

# Config shadowsocks
cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"${IP}",
    "server_port":${serverport},
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":60,
    "method":"rc4-md5"
}
EOF

#aotustart configuration
update-rc.d shadowsocks-libev defaults

#start service
/etc/init.d/shadowsocks-libev start

#if failed, start again --debian8 specified
if [ $? -ne 0 ];then
#failure indication
    echo ""
    echo "Sorry, shadowsocks-libev install failed!"
    echo "Please contact with admin@tennfy.com"
else
#success indication
    echo ""
    echo "Congratulations, shadowsocks-libev install completed!"
    echo -e "Your Server IP: ${IP}"
    echo -e "Your Server Port: ${serverport}"
    echo -e "Your Password: ${shadowsockspwd}"
    echo -e "Your Local Port: 1080"
    echo -e "Your Encryption Method:rc4-md5"
fi
}

############################### uninstall function##################################
function uninstall_shadowsocks_tennfy(){
#change the dir to shadowsocks-libev
cd $HOME
cd shadowsocks-libev

#stop shadowsocks-libev process
/etc/init.d/shadowsocks-libev stop

#uninstall shadowsocks-libev
make uninstall
make clean
cd ..
rm -rf shadowsocks-libev

# delete config file
rm -rf /etc/shadowsocks-libev

# delete shadowsocks-libev init file
rm -f /etc/init.d/shadowsocks-libev
rm -f /etc/default/shadowsocks-libev

#delete start with boot
update-rc.d -f shadowsocks-libev remove

echo "Shadowsocks-libev uninstall success!"

}

############################### update function##################################
function update_shadowsocks_tennfy(){
     uninstall_shadowsocks_tennfy
     install_shadowsocks_tennfy
	 echo "Shadowsocks-libev update success!"
}
############################### Initialization##################################
# Make sure only root can run our script
check_sanity

action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    install_shadowsocks_tennfy
    ;;
uninstall)
    uninstall_shadowsocks_tennfy
    ;;
update)
    update_shadowsocks_tennfy
    ;;	
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update}"
    ;;
esac
