#!/bin/bash -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

export ROOTFS_DIR=$DIR/rootfs
export http_proxy=http://203.17.11.110:3142
export DEBIAN_FRONTEND=noninteractive

PACKAGES="openssh-server apache2 mysql-server mysql-client
	curl sox mpg123 sqlite3 git uuid libodbc1 unixodbc unixodbc-bin
	asterisk asterisk-core-sounds-en-wav asterisk-core-sounds-en-g722
	asterisk-flite asterisk-modules asterisk-mp3 asterisk-mysql
	asterisk-moh-opsound-g722 asterisk-moh-opsound-wav asterisk-opus
	asterisk-voicemail libapache2-mod-security2
	php5.6 php5.6-cgi php5.6-cli php5.6-curl php5.6-fpm php5.6-gd php5.6-mbstring
	php5.6-mysql php5.6-odbc php5.6-xml php5.6-bcmath php-pear libicu-dev gcc
	g++ make postfix libapache2-mod-php5.6 net-tools"

do_mount() {
        if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/proc)"; then
                mount -t proc proc "${ROOTFS_DIR}/proc"
        fi

        if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/dev)"; then
                mount --bind /dev "${ROOTFS_DIR}/dev"
        fi

        if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/dev/pts)"; then
                mount --bind /dev/pts "${ROOTFS_DIR}/dev/pts"
        fi

        if ! mount | grep -q "$(realpath "${ROOTFS_DIR}"/sys)"; then
                mount --bind /sys "${ROOTFS_DIR}/sys"
        fi

}
export -f do_mount

unmount(){
	kill -9 $(lsof -F +d $ROOTFS_DIR | grep \^p | cut -c2- )
        while mount | grep -q "$ROOTFS_DIR"; do
                local LOCS
                LOCS=$(mount | grep "$ROOTFS_DIR" | cut -f 3 -d ' ' | sort -r)
                for loc in $LOCS; do
                        umount "$loc"
                done
        done
}
export -f unmount

unmount_image(){
	sync
	sleep 1
	local LOOP_DEVICES
	LOOP_DEVICES=$(losetup -j "${1}" | cut -f1 -d':')
	for LOOP_DEV in ${LOOP_DEVICES}; do
		if [ -n "${LOOP_DEV}" ]; then
			local MOUNTED_DIR
			MOUNTED_DIR=$(mount | grep "$(basename "${LOOP_DEV}")" | head -n 1 | cut -f 3 -d ' ')
			if [ -n "${MOUNTED_DIR}" ] && [ "${MOUNTED_DIR}" != "/" ]; then
				unmount "$(dirname "${MOUNTED_DIR}")"
			fi
			sleep 1
			losetup -d "${LOOP_DEV}"
		fi
	done
}
export -f unmount_image



