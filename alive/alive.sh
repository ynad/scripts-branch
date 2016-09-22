#!/bin/bash

## Check alive status of a given list of hosts by ping response
## Written by ynad - 2016.09.22

# variables
# name to indentify this server (used in emails)
serverstring=MyServerName
# hosts to test
declare -A hosts
hosts[1]=192.168.123.1
hosts[2]=foo.fqdn.net
# number ping of tries
count=6
# time delay between emails (in seconds)
maildelay=14400
# emails destination of warning emails
declare -A mailadmins
# number of emails for each line (host) of the matrix (firt element is unused!)
lenght=(0 2 1)
# first index is for hosts, second's for emails
mailadmins[1,1]=admin@foo.org
mailadmins[1,2]=someonelse@oz.net
mailadmins[2,1]=admin@foo.org
# sender email - must be configured in sSMTP settings
mailserver=alive@foo.org
# my logs & temp files
mailtext=/tmp/alive.txt
mailtime=/tmp/mailtime.txt

# $1 is the content of the email, $2 is the host interested, $3 is the destination address
function send-mail () {
	printf "To: $3\nFrom: $mailserver\nSubject: [$serverstring] ping failed: $2\n\n" > $mailtext-$2-$3
	printf "$1" >> $mailtext-$2-$3
	ssmtp "$3" < $mailtext-$2-$3 &
	sleep 2
}

# check online status
printf "Checking online status of:\n"

index=0
online=0
offline=1
for host in ${hosts[@]}; do
	printf "\t$host\t"
	index=$((index+1))

	ping -c $count $host > /dev/null
	res=$?

	# check result
	if [ $res -eq $online ]; then
		printf "\tOnline\n"
	elif [ $res -eq $offline ]; then
		printf "\tOFFLINE\n"
		timestamp=$(date +%F_%H-%M-%S)
		now=$(date +%s)

		# check time of last mail sent: avoid to spam users during long downtimes
		if [ -f $mailtime-$host ]; then
			read lastmail < $mailtime-$host
			# last one's too recent, skip
			if (( (($lastmail+$maildelay)) > $now )); then
				continue
			fi
		fi
		# send mail to every address defined in mailadmins[] for each host, and update $mailtime
		for ((j=1;j<=lenght[index];j++)) do
			send-mail "$timestamp - Warning: "$host" seems OFFLINE\n" "$host" "${mailadmins[$index,$j]}"
			printf "$now\n" > $mailtime-$host
		done
	else
		printf "\tOther error: $res\n"
	fi
done

exit 0

