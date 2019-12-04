# @author ARJUN C R (arjuncr00@gmail.com)
#
# web site https://www.acrlinux.com
#
#!/bin/bash

int_build_env()
{
export VERSION="1.0"
export SCRIPT_NAME="ACR LINUX BUILD SCRIPT"
export SCRIPT_VERSION="1.2"
export LINUX_NAME="acr-linux"
export DISTRIBUTION_VERSION="2019.12"
export ISO_FILENAME="minimal-acrlinux_x86_64-${SCRIPT_VERSION}.iso"

# BASE
export KERNEL_BRANCH="5.x" 
export KERNEL_VERSION="5.3.11"
export BUSYBOX_VERSION="1.30.1"
export SYSLINUX_VERSION="6.03"

# EXTRAS
export NCURSES_VERSION="6.1"
export NANO_VERSION="4.0"
export VIM_DIR="81"

export BASEDIR=`realpath --no-symlinks $PWD`
export SOURCEDIR=${BASEDIR}/light-os
export ROOTFSDIR=${BASEDIR}/rootfs
export ISODIR=${BASEDIR}/iso
export TARGETDIR=${BASEDIR}/debian-target/rootfs_x86_64
export BASE_ROOTFS=${BASEDIR}/base-rootfs
export BUILD_OTHER_DIR="build_script_for_other"
export BOOT_SCRIPT_DIR="boot_script"
export NET_SCRIPT="network"
export CONFIG_ETC_DIR="${BASEDIR}/os-configs/etc"
export TOOL_DIR=${BASEDIR}/tools_x86_64

#cross compile
export CROSS_COMPILE64=$TOOL_DIR/cross_gcc/x86_64-linux/bin/x86_64-linux-
export ARCH64="x86_64"
export CROSS_COMPILEi386=$TOOL_DIR/cross_gcc/i386-linux/bin/i386-linux-
export ARCHi386="i386"

#Dir and mode
export ETCDIR="etc"
export MODE="754"
export DIRMODE="755"
export CONFMODE="644"

#configs
export ACR_LINUX_KCONFIG="$BASEDIR/configs/kernel/light_os_kconfig"
export ACR_LINUX_BUSYBOX_CONFIG="$BASEDIR/configs/busybox/light_os_busybox_config"

#cflags
export CFLAGS=-m64
export CXXFLAGS=-m64

#setting JFLAG
if [ -z "$2"  ]
then	
	export JFLAG=4
else
	export JFLAG=$2
fi

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
    if [ ! -d ${ISODIR} ];
    then
        mkdir    ${ISODIR}
    fi
}

build_kernel () {
    cd ${SOURCEDIR}
			
    cd linux-${KERNEL_VERSION}
	
    if [ "$1" == "-c" ]
    then		    
    	make clean -j$JFLAG ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE
    elif [ "$1" == "-b" ]
    then	    
    	 #cp $LIGHT_OS_KCONFIG .config
    	 make defconfig CROSS_COMPILE=$CROSS_COMPILE64 ARCH=$ARCH64 bzImage \
        	-j ${JFLAG}
        cp arch/$ARCH64/boot/bzImage ${ISODIR}/kernel.gz
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

build_extras () {
    #Build extra soft
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
    find . | cpio -R root:root -H newc -o | gzip > ${ISODIR}/rootfs.gz
}


generate_image () {
}

test_qemu () {
  cd ${BASEDIR}
    if [ -f ${ISO_FILENAME} ];
    then
       qemu-system-x86_64 -m 128M -cdrom ${ISO_FILENAME} -boot d -vga std
    fi
}

clean_files () {
   rm -rf ${SOURCEDIR}
   rm -rf ${ROOTFSDIR}
   rm -rf ${ISODIR}
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
echo -e "###################################################################################################\n"

echo -e "############################Utility-${SCRIPT_VERSION} to Build x86_64 OS###########################\n"

echo -e "###################################################################################################\n"

echo -e "Help message --help\n"

echo -e "Build All: --build-all\n"

echo -e "Rebuild All: --rebuild-all\n"

echo -e "Clean All: --clean-all\n"

echo -e "Wipe and rebuild --wipe-rebuild\n" 

echo -e "Building kernel: --build-kernel --rebuild-kernel --clean-kernel\n"

echo -e "Building busybx: --build-busybox --rebuild-busybox --clean-busybox\n"

echo -e "Building other soft: --build-other --rebuild-other --clean-other\n"

echo -e "Creating root-fs: --create-rootfs\n"

echo -e "Create ISO Image: --create-img\n"

echo -e "Cleaning work dir: --clean-work-dir\n"

echo -e "Test with Qemu --Run-qemu\n"

echo "######################################################################################################"

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
