#! /bin/bash
#===============================================================================================
#   System Required:  debian or ubuntu (32bit/64bit)
#   Description:  Install Shadowsocks(libev) for Debian or Ubuntu
#   Author: tennfy <admin@tennfy.com>
#   Intro:  http://www.tennfy.com
#===============================================================================================

clear
echo '-----------------------------------------------------------------'
echo '   Install Shadowsocks(libev) for debian or ubuntu (32bit/64bit) '
echo '   Intro:  http://www.tennfy.com                                 '
echo '   Author: tennfy <admin@tennfy.com>                             '
echo '-----------------------------------------------------------------'

#color
CEND="\033[0m"
CMSG="\033[1;36m"
CFAILURE="\033[1;31m"
CSUCCESS="\033[1;32m"
CWARNING="\033[1;33m"

function Die()
{
	echo -e "${CFAILURE}[Error] $1 ${CEND}"
	exit 1
}
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
function GetDebianVersion()
{
	if [ -f /etc/debian_version ]
	then
		local main_version=$1
		local debian_version=`cat /etc/debian_version|awk -F '.' '{print $1}'`
		if [ "${main_version}" == "${debian_version}" ]
		then
		    return 0
		else 
			return 1
		fi
	else
		return 1
	fi    	
}
function InstallLibudns()
{
    export LIBUDNS_VER=0.4
    wget http://www.corpit.ru/mjt/udns/udns-$LIBUDNS_VER.tar.gz
    tar xvf udns-$LIBUDNS_VER.tar.gz
    pushd udns-$LIBUDNS_VER
    ./configure && make \
	&& cp udns.h /usr/include/ \
	&& cp libudns.a /usr/lib/ 
    if [ $? -ne 0 ]
    then
    #failure indication
        Die "Libudns installation failed!"
    fi
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
    ./configure --prefix=/usr && make && make install
	if [ $? -ne 0 ]
	then
    #failure indication
        Die "Libsodium installation failed!"
    fi
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
    make SHARED=1 CFLAGS=-fPIC && make DESTDIR=/usr install
	if [ $? -ne 0 ]
	then
    #failure indication
        Die "Mbedtls installation failed!"
    fi
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
	if [ $? -ne 0 ]
	then
    #failure indication
        Die "Shadowsocks-libev installation failed!"
    fi	
    mkdir -p /etc/shadowsocks-libev
    cp ./debian/shadowsocks-libev.init /etc/init.d/shadowsocks-libev
    cp ./debian/shadowsocks-libev.default /etc/default/shadowsocks-libev
    chmod +x /etc/init.d/shadowsocks-libev
	popd
	rm -f shadowsocks-libev-${LatestRlsVer}.tar.gz 
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

	#fix debian8 bind() problem without root user
	if GetDebianVersion 8; then
		setcap 'cap_net_bind_service=+ep' /usr/bin/ss-server
	fi
	
    # Get IP address(Default No.1)
    ip=`curl -s checkip.dyndns.com | cut -d' ' -f 6  | cut -d'<' -f 1`
    if [ -z $ip ]; then
        ip=`curl -s ifconfig.me/ip`
    fi

    #config setting
	clear
    echo '-----------------------------------------------------------------'
    echo '          Please setup your shadowsocks server                   '
    echo '-----------------------------------------------------------------'
    echo ''
	#input server port
    read -p "input server port(443 is default): " server_port
	[ -z ${server_port} ] && server_port=443
	
	echo ''
	echo '-----------------------------------------------------------------'
	echo ''
	
	#select encrypt method
	while :
	do
		echo 'Please select encrypt method:'
		echo -e "\t${CMSG}1${CEND}. AES-256-CFB"
		echo -e "\t${CMSG}2${CEND}. RC4-MD5"
		echo -e "\t${CMSG}3${CEND}. CHACHA20"
		read -p "Please input a number:(Default 1 press Enter) " encrypt_method_num
		[ -z "$encrypt_method_num" ] && encrypt_method_num=2
		if [[ ! $encrypt_method_num =~ ^[1-3]$ ]]
		then
			echo "${CWARNING} input error! Please only input number 1,2,3 ${CEND}"
		else
			if [ "$encrypt_method_num" == '1' ]
			then
				encrypt_method='aes-256-cfb'
			fi
			if [ "$encrypt_method_num" == '2' ]
			then
				encrypt_method='rc4-md5'
			fi
			if [ "$encrypt_method_num" == '3' ]
			then
				encrypt_method='chacha20'
			fi
			break
		fi
	done
	
	echo ''
	echo '-----------------------------------------------------------------'
	echo ''
	
    read -p "input password: " shadowsocks_pwd     

	echo ''
	echo '-----------------------------------------------------------------'
	echo ''

    #config shadowsocks
cat > /etc/shadowsocks-libev/config.json<<-EOF
{
    "server":"${ip}",
    "server_port":${server_port},
    "local_port":1080,
    "password":"${shadowsocks_pwd}",
    "timeout":60,
    "method":"${encrypt_method}"
}
EOF

    #add system startup
    update-rc.d shadowsocks-libev defaults

    #start service
    /etc/init.d/shadowsocks-libev start

    #if failed, start again --debian8 specified
    if [ $? -ne 0 ]
	then
    #failure indication
        echo '-----------------------------------------------------------------'
        echo -e "${CFAILURE}Sorry, shadowsocks-libev install failed!${CEND}"
        echo -e "${CFAILURE}Please contact with admin@tennfy.com${CEND}"
		echo '-----------------------------------------------------------------'
    else	
        #success indication
        echo '-----------------------------------------------------------------'
        echo -e "${CSUCCESS}Congratulations, shadowsocks-libev install completed!${CEND}"
        echo -e "Your Server IP: ${ip}"
        echo -e "Your Server Port: ${server_port}"
        echo -e "Your Password: ${shadowsocks_pwd}"
        echo -e "Your Local Port: 1080"
        echo -e "Your Encryption Method:${encrypt_method}"
		echo '-----------------------------------------------------------------'
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

    #delete configuration file
    rm -rf /etc/shadowsocks-libev

    #delete shadowsocks-libev init file
    rm -f /etc/init.d/shadowsocks-libev
    rm -f /etc/default/shadowsocks-libev

    #remove system startup
    update-rc.d -f shadowsocks-libev remove

    echo -e "${CSUCCESS}Shadowsocks uninstall success!${CEND}"
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
[ -z $1 ] && action=install
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
