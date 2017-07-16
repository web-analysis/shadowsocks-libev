#! /bin/bash
#===============================================================================================
#   System Required:  debian or ubuntu (32bit/64bit)
#   Description:  Install Shadowsocks(libev) for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================

clear
echo "#############################################################"
echo "# Install Shadowsocks(libev) for debian or ubuntu (32bit/64bit)"
echo "# Intro: http://www.tennfy.com"
echo "#"
echo "# Author: tennfy <admin@tennfy.com>"
echo "#"
echo "#############################################################"
echo ""

function CheckSanity()
{
	# Do some sanity checking.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		Die 'Must be run by root user'
	fi

	if [ ! -f /etc/debian_version ]
	then
		Die "Distribution is not supported"
	fi
}

function Die()
{
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

function InstallLibudns()
{
    export LIBUDNS_VER=0.4
    wget http://www.corpit.ru/mjt/udns/udns-$LIBUDNS_VER.tar.gz
    tar xvf udns-$LIBUDNS_VER.tar.gz
    pushd udns-$LIBUDNS_VER
    ./configure && make 
	make install
	cp udns.h /usr/include/
	cp libudns.a /usr/lib/
    popd
    ldconfig
	rm -f udns-$LIBUDNS_VER.tar.gz
}

function InstallLibsodium()
{
    export LIBSODIUM_VER=1.0.12
    wget --no-check-certificate https://github.com/jedisct1/libsodium/releases/download/$LIBSODIUM_VER/libsodium-$LIBSODIUM_VER.tar.gz
    tar xvf libsodium-$LIBSODIUM_VER.tar.gz
    pushd libsodium-$LIBSODIUM_VER
    ./configure --prefix=/usr && make 
	make install
    popd
    ldconfig
	rm -f libsodium-$LIBSODIUM_VER.tar.gz
}

function InstallMbedtls()
{
    export MBEDTLS_VER=2.5.1
    wget --no-check-certificate https://tls.mbed.org/download/mbedtls-$MBEDTLS_VER-gpl.tgz
    tar xvf mbedtls-$MBEDTLS_VER-gpl.tgz
    pushd mbedtls-$MBEDTLS_VER
    make SHARED=1 CFLAGS=-fPIC
    make DESTDIR=/usr install
    popd
    ldconfig
	rm -f mbedtls-$MBEDTLS_VER-gpl.tgz
}

function InstallShadowsocksLibev()
{
    #download latest release version of shadowsocks-libev
    export LatestRlsVer="3.0.7"
    wget --no-check-certificate https://github.com/shadowsocks/shadowsocks-libev/releases/download/v${LatestRlsVer}/shadowsocks-libev-${LatestRlsVer}.tar.gz
    tar zxvf shadowsocks-libev-${LatestRlsVer}.tar.gz 
    pushd shadowsocks-libev-${LatestRlsVer}
    ./configure --prefix=/usr && make && make install
    mkdir -p /etc/shadowsocks-libev
    cp ./debian/shadowsocks-libev.init /etc/init.d/shadowsocks-libev
    cp ./debian/shadowsocks-libev.default /etc/default/shadowsocks-libev
    chmod +x /etc/init.d/shadowsocks-libev
	popd
}

############################### install function##################################
function InstallShadowsocks()
{
    cd $HOME

    #install
    apt-get update
    apt-get install -y --force-yes gettext build-essential autoconf libtool libpcre3-dev asciidoc xmlto libev-dev automake

	#install Libsodium
    InstallLibudns
	
    #install Libsodium
    InstallLibsodium
    
    #install MbedTLS
    InstallMbedtls

    #install shadowsocks libev
	InstallShadowsocksLibev

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
    echo "input server_port(8000 is suggested):"
    read serverport
    echo "input password:"
    read shadowsockspwd

    #config shadowsocks
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
    if [ $? -ne 0 ]
	then
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
function UninstallShadowsocks()
{
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

    #delete config file
    rm -rf /etc/shadowsocks-libev

    #delete shadowsocks-libev init file
    rm -f /etc/init.d/shadowsocks-libev
    rm -f /etc/default/shadowsocks-libev

    #delete start with boot
    update-rc.d -f shadowsocks-libev remove

    echo "Shadowsocks-libev uninstall success!"
}

############################### update function##################################
function UpdateShadowsocks()
{
    UninstallShadowsocks
    InstallShadowsocks
    echo "Shadowsocks-libev update success!"
}
############################### Initialization##################################
# Make sure only root can run our script
CheckSanity

action=$1
[  -z $1 ] && action=install
case "$action" in
install)
    InstallShadowsocks
    ;;
uninstall)
    UninstallShadowsocks
    ;;
update)
    UpdateShadowsocks
    ;;	
*)
    echo "Arguments error! [${action} ]"
    echo "Usage: `basename $0` {install|uninstall|update}"
    ;;
esac
