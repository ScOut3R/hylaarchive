#!/bin/bash
#This script archives the incoming faxes recieved by HylaFax.
#
#There are two options:
#	- real-time archiving from HylaFax
#	- cron-based archiving
#
#
#Installation
#
#Needed only in real-time based operation!
#1. Copy the script in the /usr/local/bin directory.
#2. Modify the /var/spool/{hylafax,fax}/bin/faxrecvd script according to the following:
#	- Paste the following two lines at the end of the faxrcvd_mail() function.
#		echo $SENDER > /tmp/sender.log
#		/usr/local/bin/hyla_archive.sh $FILENAME 2>/tmp/fax_error_hyla.log	
#
#Made by
# Mate Gabri
# 2010-03-27
# gabrimate@duosol.hu

######
#ENVIRONMENT
#Please setup the script with these options.
######

#hylafax root directory (/var/spool/{fax,hylafax})
HYLAROOT=/var/spool/hylafax

#Operation mode
#choices:
# - realtime
# - cron
OP="realtime"

#backup directory depth
FREQUENCY="daily" #daily/monthly

#root of the backup directory
ROOT=/srv/fax

#user running hylafax
FAXUSER="uucp"

######
#!!!DO NOT CHANGE ANYTHING BELOW!!!
#Unless you know what you're doing.
######

#Working directory
TEMP=/tmp/faxbackup

#daily/monthly directory structure
YEAR=`date +%Y`
MONTH=`date +%B`
DAY=`date +%d`

case $FREQUENCY in
    daily)	TARGET=$ROOT/$YEAR/$MONTH/$DAY;;
    monthly)	TARGET=$ROOT/$YEAR/$MONTH;;
esac

#tif file of incoming fax - /var/spool/{hylafax,fax}/recvd
FILE=$1

#sender's phone number
NUM=`cat /tmp/sender.log | sed -e 's/ //g'`
if [ $NUM == "<UNSPECIFIED>" ] || [ $NUM == "" ] 
then
    NUM="UNKOWN"
fi

######
#STARTING
######

echo "Initializing..." >> /tmp/fax.log

#checking and creating target directories
targetdir()
{
	if [ ! -e "$ROOT/$YEAR" ]
	then
		mkdir -p $ROOT/$YEAR 2>>/tmp/fax_error.log
		chmod 777 $ROOT/$YEAR 2>>/tmp/fax_error.log
	fi

	if [ ! -e "$ROOT/$MONTH" ]
	then
		mkdir -p $ROOT/$YEAR/$MONTH 2>>/tmp/fax_error.log
		chmod 777 $ROOT/$YEAR/$MONTH 2>>/tmp/fax_error.log
	fi

	if [ ! -e "$TARGET" ]
	then
		mkdir -p $TARGET 2>>/tmp/fax_error.log
		chmod 777 $TARGET 2>>/tmp/fax_error.log
	fi

	if [ ! -e "$TEMP" ]
	then
		mkdir -p $TEMP 2>>/tmp/fax_error.log
	fi
}


#cron based operation
cron()
{
	echo "Checking target directory" >> /tmp/fax.log
	targetdir #calling targetdir function

	#moving incoming faxes to the working directory
	mv $HYLAROOT/recvq/*.tif $TEMP

	#convert tifs to pdf
	for TIF in $TEMP/*
	do
		tiff2pdf $TIF -o $TEMP/fax_`date +%F-%H_%M_%S`.pdf

		#remove source
		rm $TIF
		sleep 1
	done

	chown nobody:nogroup $TEMP/*.pdf
	cp -p $TEMP/*.pdf $TARGET
	rm $TEMP/*.pdf
}

#real-time operation
realtime()
{
	echo "Checking target directory" >> /tmp/fax.log
	targetdir #calling targetdir function

	#archiving
	echo "Archiving..." >> /tmp/fax.log
	cp $HYLAROOT/recvq/$FILE.tif $TEMP/$FILE.tif 2>>/tmp/fax_error.log
	tiff2pdf $TEMP/$FILE.tif -o $TEMP/$FILE.pdf 2>>/tmp/fax_error.log
	chmod 777 $TEMP/$FILE.pdf 2>>/tmp/fax_error.log
	cp -p $TEMP/$FILE.pdf $TARGET/fax_"$NUM"_`date +%F-%H_%M_%S`.pdf 2>>/tmp/fax_error.log

	#remove source
	rm $TEMP/$FILE.pdf
	rm $TEMP/$FILE.tif
}

#choose operation mode
case $OP in
    cron)	cron;;
    realtime)	realtime;;
    *)		echo "Unkown OP!" >> /tmp/fax_error.log;;
esac

echo "Finished" >> /tmp/fax.log

exit 0
