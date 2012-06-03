#!/bin/sh
# Author: Axel <grafov@gmail.com>
# License: GPL v3

## SETUP INSTRUCTIONS ##
#
#  touch /etc/mysql/backup.conf
#  chmod go-rwx /etc/mysql/backup.conf
#
# Define next variables in the configuration file:
#
# DBUSER
# DBPASS
# BAKPATH
# KEEP_DAYS
# TEMPDIR
#
# Create MySQL backup user. Example:
#  CREATE USER backup@localhost;
#  GRANT LOCK, RELOAD, SHOW DATABASES, SELECT, FILE ON *.* TO backup@localhost;
#  SET PASSWORD FOR backup@localhost = password('youpasshere');
#

. /etc/mysql/backup.conf


PARAM="--opt -u${DBUSER} -p${DBPASS}"
if [ $# -lt 1 ]
then
    DBLIST=`mysqlshow -u${DBUSER} -p${DBPASS} | grep '|' | grep -v Databases | cut -f2 -d' '`
else
    DBLIST=$1
fi

cd ${BAKPATH} 2>/dev/null || { echo $BACKPATH don\'t exists or not accessible.; exit 1; }

echo -n Cleanup of the old backups... 
cd ${BAKPATH} && find . -name '*.tar.gz' -type f -atime +${KEEP_DAYS} -exec rm -f '{}' ';'
cd ${TEMPDIR} && find . -name '*.tar.gz' -type f -atime +${KEEP_DAYS} -exec rm -f '{}' ';'
cd ${BAKPATH} && find . -name '*.md5' -type f -atime +${KEEP_DAYS} -exec rm -f '{}' ';'
echo ' complete.'


cd ${TEMPDIR} 2>/dev/null || { echo Temporary directory $TEMPDIR not ready.; exit 1; }

echo Now `date`. Database backup started.
for BASE in ${DBLIST};
do
  STAMP=`date +%Y-%m-%d-%H-%M`
  mysqladmin -u${DBUSER} -p${DBPASS} flush-tables && echo Prepare DB for backup: tables flushed.
  rm -Rf ${BASE} 2>/dev/null && echo Old backup directory removed if exists.
  mkdir ${BASE} && chmod a+rwx ${BASE} && echo New backup directory created.
  mysqldump ${PARAM} --tab=${BASE} ${BASE} && echo ${BASE} dumped.
  tar cfz ${BASE}-${STAMP}.tar.gz ${BASE} && rm -Rf ${BASE} && echo ${BASE} packed.
  md5sum ${BASE}-${STAMP}.tar.gz | cut -f1 -d' ' >${BAKPATH}/${BASE}-${STAMP}.md5
  mv ${BASE}-${STAMP}.tar.gz ${BAKPATH} && echo Archive moved to backup storage area.
  chmod go-rwx ${BAKPATH}/${BASE}-${STAMP}.tar.gz && echo Archive secured.
done;
echo Now `date`. Database backup complete.
