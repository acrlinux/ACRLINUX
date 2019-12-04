# @author ARJUN C R (arjuncr00@gmail.com)
#
# web site https://www.acrlinux.com
#
#!/bin/bash

int_build_env()
{

export SCRIPT_NAME="RASPBERRY PI OS"
export SCRIPT_VERSION="1.0"
export LINUX_NAME="acr-linux"
export DISTRIBUTION_VERSION="2019.12"
export IMAGE_NAME="minimal-acrlinux-rpi-${SCRIPT_VERSION}.img"
export BUILD_OTHER_DIR="build_script_for_other"

# BASE
export KERNEL_BRANCH="4.x" 
export KERNEL_VERSION=""
export BUSYBOX_VERSION="1.30.1"
export SYSLINUX_VERSION="6.03"
export UBOOT_VERSION="2019.10"

# EXTRAS
export NCURSES_VERSION="6.1"

# CROSS COMPILE
export ARCH="arm"
export CROSS_GCC="arm-linux-gnueabihf-"
export MCPU="cortex-a7"

export BASEDIR=`realpath --no-symlinks $PWD`
export SOURCEDIR=${BASEDIR}/light-os
export ROOTFSDIR=${BASEDIR}/rootfs
export IMGDIR=${BASEDIR}/img
export RPI_BOOT=${BASEDIR}/rpi_boot
export UBOOT_DIR=${BASEDIR}/raspberry-pi-uboot
export RPI_KERNEL_DIR=${BASEDIR}/linux
export CONFIG_ETC_DIR=${BASEDIR}/os-configs/etc
export RPI_BASE_BIN=${BASEDIR}/rpi_base_bin
export TOOL_DIR=${BASEDIR}/tools_rpi

#export CFLAGS=-m64
#export CXXFLAGS=-m64

#setting JFLAG
if [ -z "$2" ]
then
        export JFLAG=4
else
        export JFLAG=$2
fi

export CROSS_COMPILE=$TOOL_DIR/arm-bcm2708/arm-linux-gnueabihf/bin/$CROSS_GCC

}

prepare_dirs () {
    cd ${BASEDIR}
    
    if [ ! -d ${SOURCEDIR} ];
    then
        mkdir ${SOURCEDIR}
    fi
    if [ ! -d ${ROOTFSDIR} ];
    then
        mkdir ${ROOTFSDIR}
    fi
    if [ ! -d ${IMGDIR} ];
    then
        mkdir    ${IMGDIR}
	mkdir -p ${IMGDIR}/bootloader
	mkdir -p ${IMGDIR}/boot
	mkdir -p ${IMGDIR}/boot/overlays
	mkdir -p ${IMGDIR}/kernel
    fi
}

build_kernel () {
    cd ${RPI_KERNEL_DIR}
	
    if [ "$1" == "-c" ]
    then		    
    	make clean -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
    elif [ "$1" == "-b" ]
    then	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE bcm2709_defconfig
    	make -j$JFLAG  ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE zImage modules dtbs
    
    	make modules_install

    	cp arch/arm/boot/dts/*.dtb            $IMGDIR/boot/
    	cp arch/arm/boot/dts/overlays/*.dtb*  $IMGDIR/boot/overlays/
    	cp arch/arm/boot/dts/overlays/README  $IMGDIR/boot/overlays/
    	cp arch/arm/boot/zImage               $IMGDIR/kernel/rpi-kernel.img
    fi   
}

build_busybox () {
    cd ${SOURCEDIR}

    cd busybox-${BUSYBOX_VERSION}

    if [ "$1" == "-c" ]
    then	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE clean
    elif [ "$1" == "-b" ]
    then	    
    	make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE defconfig
    sed -i 's|.*CONFIG_STATIC.*|CONFIG_STATIC=y|' .config
    	make  ARCH=$arm CROSS_COMPILE=$CROSS_COMPIL busybox \
        	-j ${JFLAG}

    	make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE install \
        	-j ${JFLAG}

    	rm -rf ${ROOTFSDIR} && mkdir ${ROOTFSDIR}
    cd _install
    	cp -R . ${ROOTFSDIR}
    	rm  ${ROOTFSDIR}/linuxrc
    fi
}

build_uboot () {
	cd $UBOOT_DIR
        
	if [ -f u-boot-2019.10.tar.bz2 ]
	then
		tar -xf u-boot-2019.10.tar.bz2
		rm u-boot-2019.10.tar.bz2
	fi	

	cd u-boot-${UBOOT_VERSION}

	if [ "$1" == "-c" ]
	then       	
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE distclean
        elif [ "$1" == "-b" ]
	then	
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE rpi_defconfig
		make -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE u-boot.bin
		cp u-boot.bin $IMGDIR/bootloader
	else
	     echo "Command Not Supported"
        fi
}

build_extras () {
    #build_ncurses
    cd ${BASEDIR}/${BUILD_OTHER_DIR}
    if [ "$1" == "-c" ]
    then
    	./build_other_main.sh --clean
    elif [ "$1" == "-b" ]
    then
    	./build_other_main.sh --build	    
    fi	    
}

generate_rootfs () {	
    cd ${ROOTFSDIR}

    # sudo chown -R root:root .
    find . | cpio -R root:root -H newc -o | gzip > ${IMGDIR}/rootfs.gz
}

generate_image () {

	dd if=/dev/zero of=tmp.img iflag=fullblock bs=1M count=100 && sync

	losetup loop30 tmp.img

	mkfs -t ext4 /dev/loop30

	mkdir /mnt/rpi-disk

	mount /dev/loop30 /mnt/rpi-disk

        cp ${RPI_BASE_BIN}/bootcode.bin /mnt/rpi-disk

	cp ${RPI_BASE_BIN}/start.elf /mnt/rpi-disk

	cp ${IMGDIR}/bootloader/u-boot.bin /mnt/rpi-disk/

	echo "kernel=u-boot.bin" > /mnt/rpi-disk/config.txt

        dd if=/dev/loop30 of=${IMAGE_NAME}

	umount /dev/loop30

	rm tmp.img

	rmdir /mnt/rpi-disk

}

test_qemu () {
    cd ${BASEDIR}
    if [ -f ${IMAGE_NAME} ];
    then
	qemu-system-arm -kernel kernel_qemu/kernel-qemu -cpu arm1176 -m 256 -M versatilepb -no-reboot -serial stdio -append "root=/dev/sda2 panic=1 rootfstype=ext4 rw" -hda ${IMAGE_NAME}
    fi
    exit 1
}

clean_files () {
    rm -rf ${SOURCEDIR}
    rm -rf ${ROOTFSDIR}
    rm -rf ${ISODIR}
    rm -rf ${RPI_BOOT}
    rm -rf ${IMGDIR}
    rm -rf ${UBOOT_DIR}
    rm -rf ${RPI_KERNEL_DIR}
    
}

init_work_dir()
{
prepare_dirs
}

clean_work_dir()
{
clean_files
}

build_all()
{
build_kernel  -b
build_busybox -b
build_uboot   -b
build_extras  -b
}

rebuild_all()
{
clean_all
build_all
}

clean_all()
{
build_kernel  -c
build_busybox -c
build_uboot   -c
build_extras  -c
}

wipe_rebuild()
{
clean_work_dir
init_work_dir
rebuild_all
}

help_msg()
{
echo -e "#################################################################################\n"

echo -e "############################Utility to Build RPI OS##############################\n"

echo -e "#################################################################################\n"

echo -e "Help message --help\n"

echo -e "Build All: --build-all\n"

echo -e "Rebuild All: --rebuild-all\n"

echo -e "Clean All: --clean-all\n"

echo -e "Wipe and rebuild --wipe-rebuild\n" 

echo -e "Building kernel: --build-kernel --rebuild-kernel --clean-kernel\n"

echo -e "Building busybx: --build-busybox --rebuild-busybox --clean-busybox\n"

echo -e "Building uboot: --build-uboot --rebuild-uboot  --clean-uboot\n"

echo -e "Building other soft: --build-other --rebuild-other --clean-other\n"

echo -e "Creating root-fs: --create-rootfs\n"

echo -e "Create ISO Image: --create-img\n"

echo -e "Cleaning work dir: --clean-work-dir\n"

echo -e "Test with Qemu --Run-qemu\n"

echo "###################################################################################"

}

option()
{

if [ -z "$1" ]
then
help_msg
exit 1
fi

if [ "$1" == "--build-all" ]
then	
build_all
fi

if [ "$1" == "--rebuild-all" ]
then
rebuild_all
fi

if [ "$1" == "--clean-all" ]
then
clean_all
fi

if [ "$1" == "--wipe-rebuild" ]
then
wipe_rebuild
fi

if [ "$1" == "--build-kernel" ]
then
build_kernel -b
elif [ "$1" == "--rebuild-kernel" ]
then
build_kernel -c
build_kernel -b
elif [ "$1" == "--clean-kernel" ]
then
build_kernel -c
fi

if [ "$1" == "--build-busybox" ]
then
build_busybox -b
elif [ "$1" == "--rebuild-busybox" ]
then
build_busybox -c
build_busybox -b
elif [ "$1" == "--clean-busybox" ]
then
build_busybox -c
fi

if [ "$1" == "--build-uboot" ]
then
build_uboot -b
elif [ "$1" == "--rebuild-uboot" ]
then
build_uboot -c
build_uboot -b
elif [ "$1" == "--clean-uboot" ]
then
build_uboot -c
fi

if [ "$1" == "--build-other" ]
then
build_extras -b
elif [ "$1" == "--rebuild-other" ]
then
build_extras -c
build_extras -b
elif [ "$1" == "--clean-other" ]
then
build_extras -c
fi

if [ "$1" == "--create-rootfs" ]
then
generate_rootfs
fi

if [ "$1" == "--create-img" ]
then
generate_image
fi

if [ "$1" == "--clean-work-dir" ]
then
clean_work_dir
fi

if [ "$1" == "--Run-qemu" ]
then
test_qemu
fi

}

main()
{
int_build_env
init_work_dir
option $1
}

#starting of script
main $1 
