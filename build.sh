#!/bin/bash -x

if [ ! -e /usr/share/debootstrap/scripts/bionic ]; then
	echo "Error - you need to isntall the ubuntu debootstrap package."
	echo "Can't continue."
	exit
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

. $DIR/include.sh

mkdir -p $ROOTFS_DIR
qemu-debootstrap --components=main,contrib,non-free --include software-properties-common --arch armhf bionic $ROOTFS_DIR http://ports.ubuntu.com/ubuntu-ports

do_mount

cat $DIR/files/sources.list > $ROOTFS_DIR/etc/apt/sources.list

chroot $ROOTFS_DIR add-apt-repository ppa:ondrej/php < /dev/null
chroot $ROOTFS_DIR apt-get update
chroot $ROOTFS_DIR apt-get upgrade -y
chroot $ROOTFS_DIR apt-get -y install $PACKAGES
chroot $ROOTFS_DIR curl -sL https://deb.nodesource.com/setup_10.x | bash -
chroot $ROOTFS_DIR apt-get install -y nodejs
chroot $ROOTFS_DIR useradd -m asterisk
chroot $ROOTFS_DIR chown asterisk. /var/run/asterisk
chroot $ROOTFS_DIR chown -R asterisk. /etc/asterisk
chroot $ROOTFS_DIR chown -R asterisk. /var/{lib,log,spool}/asterisk
chroot $ROOTFS_DIR chown -R asterisk. /usr/lib/asterisk
chroot $ROOTFS_DIR chsh -s /bin/bash asterisk
rm -rf $ROOTFS_DIR/var/www/html $ROOTFS_DIR/etc/asterisk/ext* $ROOTFS_DIR/etc/asterisk/sip* 
rm -rf $ROOTFS_DIR/etc/asterisk/pj* $ROOTFS_DIR/etc/asterisk/iax* $ROOTFS_DIR/etc/asterisk/manager*
sed -i 's/.!.//' $ROOTFS_DIR/etc/asterisk/asterisk.conf
sed -i 's/\(^upload_max_filesize = \).*/\120M/' $ROOTFS_DIR/etc/php/5.6/cgi/php.ini
sed -i 's/www-data/asterisk/' $ROOTFS_DIR/etc/apache2/envvars
sed -i 's/AllowOverride None/AllowOverride All/' $ROOTFS_DIR/etc/apache2/apache2.conf
sed -i 's/ each(/ @each(/' $ROOTFS_DIR/usr/share/php/Console/Getopt.php
chroot $ROOTFS_DIR a2enmod rewrite
chroot $ROOTFS_DIR systemctl enable apache2

tar -C $ROOTFS_DIR -zxvf $DIR/files/odbc.tar.gz

chroot $ROOTFS_DIR /etc/init.d/mysql start
chroot $ROOTFS_DIR asterisk -G asterisk -U asterisk

mkdir -p $ROOTFS_DIR/usr/src
pushd $ROOTFS_DIR/usr/src
wget --continue https://mirror.freepbx.org/modules/packages/freepbx/freepbx-14.0-latest.tgz
tar zxf freepbx-14.0-latest.tgz
echo -n "Waiting for asterisk to start."
while [ ! "$(chroot $ROOTFS_DIR asterisk -rx 'core show version' | grep '^Aster')" ]; do
	echo -n .
	sleep 1
done
echo " Started"

unset http_proxy
chroot $ROOTFS_DIR bash -c 'cd /usr/src/freepbx; ./install -n'
chroot $ROOTFS_DIR fwconsole ma upgradeall
chroot $ROOTFS_DIR fwconsole ma downloadinstall announcement backup callforward callwaiting findmefollow iaxsettings ivr manager paging queues ringgroups timeconditions userman weakpasswords
# Parking has a SQL issue
#chroot $ROOTFS_DIR fwconsole ma downloadinstall --edge parking 

chroot $ROOTFS_DIR /etc/init.d/mysql stop
chroot $ROOTFS_DIR asterisk -rx 'core stop now'

unmount


