#!/bin/bash

## Automated script to ban IPs making several unauthorized connections
## Written by ynad - 2014.02.11

## Settings - adapt the following to your environment
# set the maximum number of allowed connections for each IP
maxconn=40
# warn after this number of global connections is reached
warnip=30
# system log file to monitor
syslog=/var/log/syslog
# file containing iptables rules - must implement custom chains BANLIST and BAN
iptablesconf=/etc/iptables.up.rules
# log file for humans
userlog=/root/Dropbox/FusedAdmins/ban-ip.log
# name to indentify this server (used in emails)
serverstring=Fused-Server
# email destination of warning emails
mailadmin=ynad92@gmail.com
# sender email - must be configured in sSMTP settings
mailserver=fused.server@gmail.com
# my logs & temp files
iplog=/tmp/ips.log
banlog=/root/.config/ban-ip.log
warnnum=/root/.config/warn-num.log
mailtext=/tmp/ban-mail.txt
# declare patterns to search ("--log-prefix" in iptables logging, case sensitive)
pattern1=SSH-in
pattern2=VPN-in
pattern3=VPN2-in
# network interface to monitor (to monitor more than one, add "-e $ifwalX" after "grep -e $ifwal1" in function extract-ips)
ifwal1=fused_pub
# misc
declare -A freq
declare -A ips


function syntax {
    printf "Syntax:\n banip.sh [-h | --help] [-l \"different-syslogFile\"]\n"
}

function extract-ips {
    cat $syslog | sed -n -e "s/^.*$pattern1//p" -e "s/^.*$pattern2//p" -e "s/^.*$pattern3//p" | grep -e $ifwal1 | cut -c 2- | cut -d " " -f 4 | cut -c 5- > $iplog
}

# build frequencies of IPs (using IPs as indexes)
function ip-frequencies {
    for ip in $(cat $iplog); do
        ((freq[$ip]+=1))
    done
}

# read updated $warnip value, if exists
function warnip-update {
    if [ -f $warnnum ]; then
        read num < $warnnum
        let "warnip = $warnip + $num"
    fi
}

function update-iptables {
    iptables-restore $iptablesconf
}

function ban-ip () {
    # check if found IP was already banned, if not ban it now
    for ip in $(cat $banlog); do
        if [ $ip == $1 ]; then
            echo "---> IP: ${1} was already banned!"
            return 1
        fi
    done
    echo "${1}" >> $banlog
    echo "---> Banning IP: ${1}"
    # BANLIST and BAN iptables chains required for this to work
    sed -i '/-A BANLIST -j RETURN/i-A BANLIST -i '${ifwal1}' -s '${1}'/32 -j BAN' $iptablesconf
}

function send-mail () {
    printf "To: $mailadmin\nFrom: $mailserver\nSubject: $serverstring: connections warning\n\n" > $mailtext
    printf "$1" >> $mailtext
    ssmtp $mailadmin < $mailtext &
}


# check user permissions
if [ "$USER" != "root" ] && [ "$USER" != "" ]; then
    syntax
    echo "This script must be run as root!"
    exit 1
fi

# arguments check
if [ $# -gt 0 ]; then
    if [ "$1" == "-h" -o "$1" == "--help" ]; then
        syntax
        exit 0
    # reset log of global connections reached - must be executed once a day after syslog pruning
    elif [ "$1" == "--reset" ]; then
        rm -f $warnnum
        exit 0
    # parse different syslog, passed as argument
    else
        syslog=$1
    fi
fi

# extract IPs
extract-ips

# build frequencies of IPs (using IPs as indexes)
ip-frequencies

# read updated $warnip value, if exists
warnip-update

i=0
flag=0
id=1
# build IPs list and perform banning
printf "Connections in \"$syslog\" (max conn. allowed = $maxconn):\n"
for ip in $(cat $iplog | sort -n | uniq); do
    # fill list of unique IPs
    ips[$i]=$ip
    printf "%3d: - %-15s\t- freq: %3d\n" "$id" "${ips[$i]}" "${freq[${ips[$i]}]}"
    # ban if exceeds max number of connections allowed
    if [ ${freq[${ips[$i]}]} -gt $maxconn ]; then
        ban-ip ${ips[$i]}
        # do not update userlog if IP was already banned
        if [ $? -ne 1 ]; then
            ((flag+=1))
            timestamp=$(date +%F_%H-%M-%S)
            printf "$timestamp - Banning IP: ${ips[$i]}, \tfreq: ${freq[${ips[$i]}]}\n" >> $userlog
            send-mail "$timestamp - Banning IP: ${ips[$i]}, \tfreq: ${freq[${ips[$i]}]}\n"
        fi
    fi
    ((id+=1))
    ((i+=1))
    # warn if more than $warnip global connections
    let "rest = $i % $warnip"
    if [ $rest -eq 0 ]; then
        timestamp=$(date +%F_%H-%M-%S)
        printf "$timestamp - Warning: reached $i connections\n" >> $userlog
        printf "$i\n" > $warnnum
        send-mail "$timestamp - Warning: reached $i connections\n"
    fi
done

# apply ban if new rules were added
if [ $flag -ne 0 ]; then
    update-iptables
    echo "Banned $flag IPs!"
else
    echo "No IP banned."
fi


exit 0

