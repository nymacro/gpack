#!/bin/bash
# GPack Package Manager
# Package Manager Internals
# $Id: gpack.sh,v 1.10 2005/06/13 11:31:01 nymacro Exp $

########################################################################
#
# Copyright 2005
# Aaron Marks.
#
# GPack is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.
#
# GPack is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License
# along with GPack; see the file COPYING.  If not, write to the Free
# Software Foundation, 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.
#
########################################################################

# CONFIGURATION
VERSION=0.9.0

# Load configuration
if ! . ./gpack.conf ; then
    echo "Failed to locate 'gpack.conf', aborting."
    exit 1
fi

# Package descriptor repositry
#PKG_FILE_DIR=/home/nym/projects/gpack-clean/packages
# Installed package configuration dir
#PKG_CONF_DIR=/home/nym/projects/gpack-clean/config
# Root filesystem to install packages
#PKG_ROOT_DIR=/home/nym/projects/gpack-clean/root
# Build log
#PKG_LOG=/home/nym/projects/gpack-clean/build.log

# Name of package build descriptor
#PKG_FILE=SATPKG
#PKG_EXTENSION=satpkg.tar.gz

########
# FUNCTIONS

# Default optional package file functions
pre_install() {
    echo "pre-install" > /dev/null
}

post_install() {
    echo "post-install" > /dev/null
}

pre_remove() {
    echo "pre-remove" > /dev/null
}

post_remove() {
    echo "post-remove" > /dev/null
}

########

# Name: error <message>
# Desc: Print error message to screen then abort
error() {
    echo "ERROR: $1"
    exit 1
}

# Name: warn <message>
# Desc: Warn the user about something.
warn() {
    echo "WARNING: $1"
}

# Name: pkg_find <package name>
# Desc: Find and return package location
pkg_find() {
    local found=`find $PKG_FILE_DIR -maxdepth 2 -name "$1" -type d -not -name work`
    if [ -d "$found" ]; then
	# return success!
	echo "$found"
	return 0
    fi
    return 1
}

# Name: pkg_version <package directory>
# Desc: Returns version of package
pkg_version() {
    if ! . $1/$PKG_FILE ; then
	error "Could not find $PKG_FILE"
    fi

    echo "$version"
    return 0
}

# Name: pkg_info <package dir>
# Desc: Prints package information to screen
pkg_info() {
    if ! . $1/$PKG_FILE ; then
	error "Failed to find package file."
    fi

    echo "name:        $name"
    echo "version:     $version"
    echo "release:     $release"
    echo "license:     $license"
    echo "group:       $group"
    echo "description: $description"

    echo "source:"
    for i in "${source[@]}"; do
	echo "    $i"
    done

    echo "depends:"
    for i in "${depends[@]}"; do
	echo "    $i"
    done

    echo "optdeps:"
    for i in "${optdeps[@]}"; do
	echo "    $i"
    done

    echo "conflicts:"
    for i in "${conflicts[@]}"; do
	echo "    $i"
    done
}

# Name: pkg_meets <package criteria>
# Desc: Return success if package meets criteria
pkg_meets() {
    if ! pkg_installed $1 ; then
	return 1
    fi

    # package name
    local PKG_NAME=`echo $1 | awk '{print $1;}'`
    # operator
    local PKG_OPER=`echo $1 | awk '{print $2;}'`
    # version need
    local PKG_NEED=`echo $1 | awk '{print $3;}'`

    # package path
    local PKG_PATH=`pkg_find $PKG_NAME`
    if [ "$PKG_PATH" == "" ]; then
	error "Could not find package"
    fi

    # current version
    local PKG_VERSION=`pkg_version $PKG_PATH`

    case $PKG_OPER in
	">")
	    if [[ $PKG_VERSION > $PKG_NEED ]]; then
		return 0
	    fi
	    ;;
	">=")
	    if [[ $PKG_VERSION > $PKG_NEED || $PKG_VERSION == $PKG_NEED ]]; then
		return 0
	    fi
	    ;;
	"<")
	    if [[ $PKG_VERSION < $PKG_NEED ]]; then
		return 0
	    fi
	    ;;
	"<=")
	    if [[ $PKG_VERSION < $PKG_NEED || $PKG_VERSION == $PKG_NEED ]]; then
		return 0
	    fi
	    ;;
	"")
	    return 0
	    ;;
	*)
	    error "Bad operator"
	    ;;
    esac
    return 1
}

# Name: pkg_build <package location>
# Desc: Build package from package file.
pkg_build() {
    if ! . $1/$PKG_FILE ; then
	error "Could not find $PKG_FILE"
    fi

    # make sure that the needed variables exist
    if [ "$name" == "" ]; then
	error "'name' not specified"
    fi
    if [ "$version" == "" ]; then
	error "'version' not specified"
    fi
    if [ "$release" == "" ]; then
	error "'release' not specified"
    fi

    # check to see if the package already exists
    if [ -e "$1/$name-$version-$release.$PKG_EXTENSION" ]; then
	warn "Package already built ($name)"
	return 0
    fi

    # check dependancies
    for i in "${depends[@]}"; do
	if ! pkg_meets $i; then
	    error "Dependancies not met"
	fi
    done

    for i in "${optdeps[@]}"; do
	if ! pkg_meets $i; then
	    warn "Optional dependancy not installed."
	fi
    done

    for i in "${conflicts[@]}"; do
	if pkg_meets $i; then
	    error "Conflicting packages ($i)"
	fi
    done

    # set up build environment
    # source/build directory
    local WORK=$1/work
    local SRC=$WORK/src
    # package base directory
    local PKG_BASE=$WORK/pkg
    # package installation directory
    local PKG=$PKG_BASE/pkg

    if [ -d "$WORK" ]; then
	rm -rf $WORK
    fi

    mkdir $WORK
    mkdir $SRC
    mkdir $PKG_BASE
    mkdir $PKG

    local PKGMK_SOURCE_DIR=$1

    # make sure source is available
    echo 'Getting source'
    for i in "${source[@]}"; do
	local SRC_FILE=`echo $i | sed 's|.*/||'`
	if [ ! -e "$1/$SRC_FILE" ]; then
	    if ! (cd $1 && wget $i); then
		error "Failed to retrieve source."
	    fi
	fi

	# copy/extract files
	(
	    cd $1 &&
	    case `echo $SRC_FILE | sed -e 's/.*\.//'` in
		gz | tgz)
		    tar xzf $SRC_FILE -C $SRC
		    ;;
		bz2)
		    tar xjf $SRC_FILE -C $SRC
		    ;;
		zip)
		    unzip $SRC_FILE -d $SRC
		    ;;
		*)
		    cp $SRC_FILE $SRC
		    ;;
	    esac
	) || error "Extracting source"
    done

    # check checksum of source files
    if [ -e "$1/checksum" ]; then
	echo "Checking source integrity..."
	for i in "${source[@]}"; do
	    local SRC_FILE=`echo $i | sed 's|.*/||'`
	    local CHKSUM=`cat $1/checksum | grep $SRC_FILE | awk '{print $1;}'`
	    local FILE_CHKSUM=`(cd $1; md5sum $SRC_FILE) | awk '{print $1;}'`
	    if [ ! "$FILE_CHKSUM" == "$CHKSUM" ]; then
		echo "MD5 Mismatch ($SRC_FILE)"
		echo "Checksum:  $CHKSUM"
		echo "Should be: $FILE_CHKSUM"
		rm -rf $WORK
		exit 1
	    fi
	done
    else
	echo "Generating checksum for source files..."
	for i in "${source[@]}"; do
	    local SRC_FILE=`echo $i | sed 's|.*/||'`
	    local CHKSUM=`md5sum $1/$SRC_FILE`
	    local MD5=`echo $CHKSUM | awk '{print $1;}'`
	    echo "$MD5 $SRC_FILE" >> $1/checksum
	done
    fi

    # build
    echo "Build"
    #if ! (cd $SRC && build > $PKG_LOG) ; then
    if ! (cd $SRC && build) ; then
	rm -rf $WORK
	error "'build' failed"
    fi

    # build package
    echo 'Creating package'

    cp $1/$PKG_FILE $PKG_BASE

    # create package footprint
    STAT_FORMAT='%b %a %U %G %n'
    for i in `find $PKG`; do
	stat -c "$STAT_FORMAT" $i | sed "s|$PKG||" >> $PKG_BASE/footprint
    done

    # create package format info
    echo "GPack $VERSION " `date` > $PKG_BASE/info

    # archive
    if (cd $PKG_BASE && tar czf $1/$name-$version-$release.$PKG_EXTENSION *) ; then
	echo "Package created"
    else
	error "Failed to create package"
    fi

    cat $PKG_BASE/footprint

    rm -rf $WORK
}

# Name: pkg_install <package file>
# Desc: Installs package.
pkg_install() {
    local TMP=/tmp/gpack-`date +%s`
    mkdir $TMP

    if ! tar xzf $1 -C $TMP ; then
	error "Could not extract package"
    fi

    (
	cd $TMP
	if ! . ./$PKG_FILE ; then
	    error "Invalid package format"
	fi

	if pkg_installed $name ; then
	    echo "ERROR: Package already installed ($name)"
	    return 0
	fi

        # check dependancies
	for i in "${depends[@]}"; do
	    if ! pkg_meets $i; then
		error "Dependancies not met"
	    fi
	done
	
	for i in "${optdeps[@]}"; do
	    if ! pkg_meets $i; then
		warn "Optional dependancy not installed."
	    fi
	done


	for i in "${conflicts[@]}"; do
	    if pkg_meets $i; then
		error "Conflicting packages ($i)"
	    fi
	done

	# run pre-install
	pre_install

	# match footprint
	local INSTOK=0
	for i in `cat footprint | awk '{print $5;}'`; do
	    if [ -e "$PKG_ROOT_DIR/$i" ]; then
                if [ ! -d "$PKG_ROOT_DIR/$i" ]; then
		    warn "File already exists on system ($i)"
		    INSTOK=1
                fi
	    fi
	done

	if [ "$INSTOK" == "1" ]; then
	    if [ ! "$FORCE_OVERWRITE" = "yes" ]; then
		error "Aborted install"
	    fi
	fi

	# install the files
	#cp -r $TMP/pkg/* $PKG_ROOT_DIR
	for i in `cat footprint | awk '{print $5;}'`; do
	    if [ -d "$TMP/pkg/$i" ]; then
		if [ ! -d "$PKG_ROOT_DIR/pkg/$i" ]; then
		    mkdir -p $PKG_ROOT_DIR/$i
		fi
	    else
		mv $TMP/pkg/$i $PKG_ROOT_DIR/$i
	    fi
	done

	#
	mkdir $PKG_CONF_DIR/$name

	mv $PKG_FILE $PKG_CONF_DIR/$name/
	mv footprint $PKG_CONF_DIR/$name/

	# run post install
	post_install
    ) || exit 1

    rm -rf $TMP

    echo "Installed $1"
}

# Name: pkg_remove <package name>
# Desc: Remove package with name.
pkg_remove() {
    if [ ! -d "$PKG_CONF_DIR/$1" ]; then
	error "Package not installed"
    fi

    (
	if ! . $PKG_CONF_DIR/$1/$PKG_FILE ; then
	    error "Could not find package file"
	fi
	
	pre_remove
	
        # remove
	for i in `cat $PKG_CONF_DIR/$1/footprint | awk '{print $5;}' | sort -r`; do
	    if [ -d "$PKG_ROOT_DIR/$i" ]; then
		rmdir $PKG_ROOT_DIR/$i > /dev/null 2>&1
	    else
		rm $PKG_ROOT_DIR/$i > /dev/null 2>&1
	    fi
	done
	
	post_remove
	
        # remove installation info
	rm -r $PKG_CONF_DIR/$1
    ) || exit 1
    echo "Removed $1"
}

# Name: pkg_installed <package name>
# Desc: Return success if package is installed else false.
pkg_installed() {
    if [ -d  "$PKG_CONF_DIR/$1" ]; then
	return 0
    fi
    return 1
}

# Name: pkg_depinst <package dir>
# Desc: Install package & all dependancies
pkg_depinst() {
    (
	if ! . $1/$PKG_FILE ; then
	    error "Could not find package config"
	fi
	
        # check dependancies
	for i in "${depends[@]}"; do
	    if ! pkg_meets $i; then
		if ! (depends=(); conflicts=(); optdeps=(); pkg_depinst `pkg_find $i`); then
		    error "Installing dependancies"
		fi
	    fi
	done
	
	for i in "${optdeps[@]}"; do
	    if ! pkg_meets $i; then
		warn "Optional dependancy not installed."
	    fi
	done

	for i in "${conflicts[@]}"; do
	    if pkg_meets $i; then
		error "Conflicting packages ($i)"
	    fi
	done
	
	echo "-- $1"
	local PKG_NAME="$1/$name-$version-$release.$PKG_EXTENSION"
	if [ ! -e "$PKG_NAME" ]; then
	    if ! pkg_build $1 ; then
		error "Build failed"
	    fi
	fi
	pkg_install "$1/$name-$version-$release.$PKG_EXTENSION"
    ) || exit 1
}
