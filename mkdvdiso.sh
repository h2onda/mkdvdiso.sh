#!/bin/bash

# by Chris Kloiber <ckloiber@redhat.com>

# A quick hack that will create a bootable DVD iso of a Red Hat Linux
# Distribution. Feed it either a directory containing the downloaded
# iso files of a distribution, or point it at a directory containing
# the "RedHat", "isolinux", and "images" directories.

# This version only works with "isolinux" based Red Hat Linux versions.

# Lots of disk space required to work, 3X the distribution size at least.

# GPL version 2 applies. No warranties, yadda, yadda. Have fun.


if [ $# -lt 2 ]; then
	echo "Usage: `basename $0` source /destination/DVD.iso"
	echo ""
	echo "        The 'source' can be either a directory containing a single"
	echo "        set of isos, or an exploded tree like an ftp site."
	exit 1
fi

IMPLANTISOMD5="/usr/lib/anaconda-runtime/implantisomd5"
if [ ! -x ${IMPLANTISOMD5} ]; then
	IMPLANTISOMD5=`which implantisomd5 2> /dev/null`
fi
if [ -z ${IMPLANTISOMD5} ]; then
	echo "please install isomd5sum or anaconda-runtime !" > /dev/stderr
	exit 1
fi

CHECKISOMD5="/usr/lib/anaconda-runtime/checkisomd5"
if [ ! -x ${CHECKISOMD5} ]; then
	CHECKISOMD5=`which checkisomd5 2> /dev/null`
fi
if [ -z ${CHECKISOMD5} ]; then
	echo "please install isomd5sum or anaconda-runtime !" > /dev/stderr
	exit 1
fi

cleanup() {
[ ${LOOP:=/tmp/loop} = "/" ] && echo "LOOP mount point = \/, dying!" && exit
[ -d $LOOP ] && rm -rf $LOOP 
[ ${DVD:=~/mkrhdvd} = "/" ] && echo "DVD data location is \/, dying!" && exit
[ -d $DVD ] && rm -rf $DVD 
}

cleanup
mkdir -p $LOOP
mkdir -p $DVD

if [ !`ls $1/*.iso 2>&1>/dev/null ; echo $?` ]; then
	echo "Found ISO CD images..."
	CDS=`expr 0`
	DISKS="1"
	ISOFILES=`ls $1/*.iso`

	for f in ${ISOFILES}; do
		echo "checking `basename $f` ..."
		${CHECKISOMD5} $f 2>&1 > /dev/null 
		if [ $? -ne 0 ]; then
			exit 1
		fi
		echo
	done

	for f in `ls $1/*.iso`; do
		mount -o loop $f $LOOP
		cp -av $LOOP/* $DVD
		if [ -f $LOOP/.discinfo ]; then
			cp -av $LOOP/.discinfo $DVD
			CDS=`expr $CDS + 1`
			if [ $CDS != 1 ] ; then
                        	DISKS=`echo ${DISKS},${CDS}`
                	fi
		fi
		umount $LOOP
	done
	if [ -e $DVD/.discinfo ]; then
		awk '{ if ( NR == 4 ) { print disks } else { print ; } }' disks="$DISKS" $DVD/.discinfo > $DVD/.discinfo.new
		mv $DVD/.discinfo.new $DVD/.discinfo
	fi
else
	echo "Found FTP-like tree..."
	cp -av $1/* $DVD
	[ -e $1/.discinfo ] && cp -av $1/.discinfo $DVD
fi

rm -rf $DVD/isolinux/boot.cat
find $DVD -name TRANS.TBL | xargs rm -f

cd $DVD
mkisofs -J -R -v -T -o $2 -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table .
${IMPLANTISOMD5} --force $2

cleanup
echo ""
echo "Process Complete!"
echo ""
