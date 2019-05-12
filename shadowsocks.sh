#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
clear
libsodium_file="libsodium-1.0.17"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/1.0.17/libsodium-1.0.17.tar.gz"
cur_dir=`pwd`
ciphers=(
aes-256-gcm
aes-192-gcm
aes-128-gcm
aes-256-ctr
aes-192-ctr
aes-128-ctr
aes-256-cfb
aes-192-cfb
aes-128-cfb
camellia-128-cfb
camellia-192-cfb
camellia-256-cfb
chacha20-ietf-poly1305
chacha20-ietf
chacha20
rc4-md5
)
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
# Stream Ciphers
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        setenforce 0
    fi
}

#Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Get public IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}
    # Set shadowsocks config password
    echo "Please enter your shadowsocks password la"
    read -p "(Default password:${shadowsockspwd}):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="${shadowsockspwd}"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    # Set shadowsocks config port
    while true
    do
    dport=$(shuf -i 9000-19999 -n 1)
    echo "Please enter a shadowsocks port [1-65535]"
    read -p "(Default port: ${dport}):" shadowsocksport
    [ -z "$shadowsocksport" ] && shadowsocksport=${dport}
    expr ${shadowsocksport} + 1 &>/dev/null
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        fi
        done
    # Set shadowsocks config stream ciphers
    while true
    do
    echo -e "Please select stream cipher for shadowsocks-python:"
    for ((i=1;i<=${#ciphers[@]};i++ )); do
        hint="${ciphers[$i-1]}"
        echo -e "${green}${i}${plain}) ${hint}"
    done
    read -p "Which cipher you'd select(Default: ${ciphers[0]}):" pick
    [ -z "$pick" ] && pick=1
    expr ${pick} + 1 &>/dev/null
    shadowsockscipher=${ciphers[$pick-1]}
    echo
    echo "---------------------------"
    echo "cipher = ${shadowsockscipher}"
    echo "---------------------------"
    echo
    break
    done

    echo
    echo "Press any key to start.l"
    char=`get_char`
    # Install necessary dependencies
    if check_sys packageManager yum; then
        yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
    elif check_sys packageManager apt; then
        apt-get -y update
        apt-get -y install python python-dev python-setuptools openssl libssl-dev curl wget unzip gcc automake autoconf make libtool
    fi
    cd ${cur_dir}
}

# Download files
download_files(){
    # Download libsodium file
    if ! wget --no-check-certificate -O ${libsodium_file}.tar.gz ${libsodium_url}; then
        echo -e "[${red}Error${plain}] Failed to download ${libsodium_file}.tar.gz!"
        exit 1
    fi
    # Download Shadowsocks file
    if ! wget --no-check-certificate -O shadowsocks-master.zip https://github.com/shadowsocks/shadowsocks/archive/master.zip; then
        echo -e "[${red}Error${plain}] Failed to download shadowsocks python file!"
        exit 1
    fi
}

# Config shadowsocks
config_shadowsocks(){
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":300,
    "method":"${shadowsockscipher}",
    "fast_open":false
}
EOF
}

# Firewall set
firewall_set(){
    echo -e "[${green}Info${plain}] firewall set start..."
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "[${green}Info${plain}] port ${shadowsocksport} has already been set up."
            fi
        else
            echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed, please manually set it if necessary."
        fi
}

# Install Shadowsocks
install(){
    # Install libsodium
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] libsodium install failed!"
            install_cleanup
            exit 1
        fi
    fi

    ldconfig
    # Install Shadowsocks
    cd ${cur_dir}
    unzip -q shadowsocks-master.zip
    if [ $? -ne 0 ];then
        echo -e "[${red}Error${plain}] unzip shadowsocks-master.zip failed! please check unzip command."
        install_cleanup
        exit 1
    fi

    cd ${cur_dir}/shadowsocks-master
    python setup.py install --record /usr/local/shadowsocks_install.log

    if [ -f /usr/bin/ssserver ] || [ -f /usr/local/bin/ssserver ]; then
        chmod +x /etc/init.d/shadowsocks
        if check_sys packageManager yum; then
            chkconfig --add shadowsocks
            chkconfig shadowsocks on
        elif check_sys packageManager apt; then
            update-rc.d -f shadowsocks defaults
        fi
        /etc/init.d/shadowsocks start
    else
        echo
        echo -e "[${red}Error${plain}] Shadowsocks install failed! please visit https//:www.baiadu.com and contact."
        install_cleanup
        exit 1
    fi

    clear
    echo
    echo -e "Congratulations, Shadowsocks-python server install completed!"
    echo -e "Your Server IP        : \033[41;37m $(get_ip) \033[0m"
    echo -e "Your Server Port      : \033[41;37m ${shadowsocksport} \033[0m"
    echo -e "Your Password         : \033[41;37m ${shadowsockspwd} \033[0m"
    echo -e "Your Encryption Method: \033[41;37m ${shadowsockscipher} \033[0m"
    echo
    echo "Welcome to visit:ttps//:www.baiadu.com"
    echo "Enjoy it!"
    echo
}

# Install cleanup
install_cleanup(){
    cd ${cur_dir}
    rm -rf shadowsocks-master.zip shadowsocks-master ${libsodium_file}.tar.gz ${libsodium_file}
}
esac
