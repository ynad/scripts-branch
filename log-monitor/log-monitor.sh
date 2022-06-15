#!/bin/bash

## Automated script to monitor system logs, and send a report by mail
## Written by ynad - v0.2, 2022.06.15

## Settings - adapt the following to your environment
# name to indentify this server (used in emails)
serverstring=My-Server
# email destination of warning emails
mailadmin=myemail@myserver.com
# sender email - must be configured in sSMTP settings
mailserver=myserver@myserver.com
# my logs & temp files
weeklog=/tmp/syslog-week.log
dayslog=/tmp/syslog-days.log.xz.tar
mailtext=/tmp/ban-mail.txt
report=/tmp/report.txt
tmplog=/tmp/syslog
# declare patterns to search ("--log-prefix" in iptables logging, case sensitive)
declare -a patterns=( "SSH-in" "VPN-in" "BANNED" "WHITELIST" "DOS" "TCP 80 Burst Exhausted" "TCP 443 Burst Exhausted" "Torrent blocked" "Sent mail" )


function syntax {
	printf "Syntax:\n log-monitor.sh [-h | --help]\n"
}


function join-logs {
	cp /var/log/syslog* /tmp/
	mv $tmplog $tmplog.0
	for id in {1..8}; do
		let "id = 8 - id"
		if [ $id -gt 1 ]; then
			gzip -d $tmplog.${id}
		fi
		cat $tmplog.${id} >> $weeklog
	done
}


function clean {
	rm $tmplog*
}


function send-mail () {
	printf "To: $mailadmin\nFrom: $mailserver\nSubject: [$serverstring]: system logs report\n\n" > $mailtext
	#printf "$1" >> $mailtext
	cat $report >> $mailtext
	msmtp $mailadmin < $mailtext &
}


function attachment {
	printf "\n" >> $report
	# compress
	tar -cJf $weeklog.xz.tar $weeklog > /dev/null 2>&1
	tar -cJf $dayslog $tmplog.* > /dev/null 2>&1
	# paste to file
	uuencode $weeklog.xz.tar $weeklog.xz.tar >> $report
	printf "\n" >> $report
	uuencode $dayslog $dayslog >> $report
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
	fi
fi


# make an unique log file
join-logs

# generate report
timestamp=$(date +%F_%H-%M-%S)
printf "System logs report for \"$serverstring\", at $timestamp\n\n" > $report

# whole week
printf "Global report of last week:\n" >> $report
for i in "${patterns[@]}"; do
	printf "Pattern: %25s   -   events: %3d\n" "$i" "$(cat $weeklog | grep -c "$i")" >> $report
done

# and single days
for id in {1..8}; do
	let "id = 8 - id"
	printf "\nReport for $id days ago:\n" >> $report
	for i in "${patterns[@]}"; do
		printf "Pattern: %25s   -   events: %3d\n" "$i" "$(cat $tmplog.${id} | grep -c "$i")" >> $report
	done
done

# se busca un hombre - vero capri
cat $report

# attach logs
attachment

# send email
send-mail

clean
exit 0
