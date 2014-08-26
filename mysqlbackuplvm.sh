#!/bin/bash
# Backup MySQL par LVM
# A. NANOT 23-01-2013
# Droits de l'utilisation MYSQL : SELECT, FILE, LOCK TABLES, RELOAD, SHUTDOWN

USER="mysqlbackup"
PASSWORD="XXXX"
HOSTNAME=`hostname -s`
HOST='localhost'
DATE=`date "+%d%m%Y"`
DATABASE="portail"
LOGFILE="/var/log/mysqld-snapshot-script.log"
MYSQLDIRECTOTY="/var/lib/mysql"
BACKUPDIRECTORY="/var/bckmysqllvm"
DUMPDIRECTORY="/var/dumpsbdd"
VGNAME=`df /var/lib/mysql | grep -i dev | xargs /sbin/lvdisplay | grep 'VG\ Name' | awk {'print $3'}`
LVNAME=`df /var/lib/mysql | grep -i dev | xargs /sbin/lvdisplay | grep 'LV\ Name' | cut -d/ -f4`
SNAPNAME="snapmysqllv"
INNODBLOGFILESIZE=`mysqladmin variables -u$USER -p$PASSWORD -h$HOST | grep -i innodb_log_file_size | awk {'print $4'}`

echo "********** Sauvegarde des bases MySQL du :" $DATE  "**********" >> $LOGFILE 2>&1

if [ `mount | grep "$MYSQLDIRECTOTY" | wc -l` -ne 0 ] && [ -d $BACKUPDIRECTORY ]
then
mysql -u$USER -p$PASSWORD -h$HOST<< EOF
        FLUSH TABLES WITH READ LOCK;
        system /sbin/lvcreate -l +100%FREE --snapshot -n $SNAPNAME /dev/$VGNAME/$LVNAME >> $LOGFILE 2>&1;
        UNLOCK TABLES;
        quit
EOF
	mount -t ext4 /dev/$VGNAME/$SNAPNAME $BACKUPDIRECTORY >> $LOGFILE 2>&1
else echo $DATE : "Le repertoire d'installation MySQL ou le repertoire de backup n'existent pas" >> $LOGFILE 2>&1 && exit 1;
fi

if [ `mount | grep "$BACKUPDIRECTORY" | wc -l` -ne 0 ] && [ -d $DUMPDIRECTORY ]
then
	mysqld_safe --no-defaults --port=3307 --socket=/var/run/mysqld/mysqld-snapshot.sock --log-error=/var/log/mysqld-snapshot.log --pid-file=/var/run/mysqld/mysqld-snapshot.pid --datadir=$BACKUPDIRECTORY --innodb-log-file-size=$INNODBLOGFILESIZE >> $LOGFILE 2>&1 &
	sleep 60
	mysqldump -S /var/run/mysqld/mysqld-snapshot.sock -u$USER -p$PASSWORD --log-error=/var/log/mysqld-snapshot.log --opt --quick $DATABASE --host $HOST | gzip > $DUMPDIRECTORY/backup.portail.$DATE.sql.gz
	md5sum -t $DUMPDIRECTORY/backup.portail.$DATE.sql.gz > $DUMPDIRECTORY/backup.portail.$DATE.sql.gz.md5
	mysqladmin -S /var/run/mysqld/mysqld-snapshot.sock -u$USER -p$PASSWORD -h$HOST shutdown >> $LOGFILE 2>&1
	umount $BACKUPDIRECTORY >> $LOGFILE 2>&1
	/sbin/lvremove -f /dev/$VGNAME/$SNAPNAME >> $LOGFILE 2>&1
else 
	umount $BACKUPDIRECTORY
        /sbin/lvremove -f /dev/$VGNAME/$SNAPNAME >> $LOGFILE 2>&1
	echo $DATE : "Le repertoire de backup ou le repertoire de dumps n'existent pas" >> $LOGFILE 2>&1 
	exit 1
fi

find $DUMPDIRECTORY -type f -ctime +5 -name "backup*" -exec rm -vrf {} \; >> $LOGFILE 2>&1
