#!/bin/bash
# GPack Package Manager
# Package Manager Internals
# $Id: gpack.sh,v 1.17 2005/07/04 00:34:46 nymacro Exp $

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
VERSION=0.9.1

# Load configuration
if ! . ./gpack.conf ; then
    echo "Failed to locate 'gpack.conf', aborting."
    exit 1
fi

# ensure that all required config is set
if [ -z "$PKG_CONF_DIR" ]; then
    echo "PKG_CONF_DIR not set in gpack.conf"
    exit 1
fi

if [ -z "$PKG_FILE_DIR" ]; then
    echo "PKG_FILE_DIR not set in gpack.conf"
    exit 1
fi

if [ -z "$PKG_ROOT_DIR" ]; then
    echo "PKG_ROOT_DIR not set in gpack.conf"
    exit 1
fi

if [ -z "$PKG_SOURCE_DIR" ]; then
    echo "PKG_SOURCE_DIR not set in gpack.conf"
    exit 1
fi

if [ -z "$PKG_PACKAGE_DIR" ]; then
    echo "PKG_PACKAGE_DIR not set in gpack.conf"
    exit 1
fi

# create dirs if not exist
if [ ! -d "$PKG_CONF_DIR" ]; then
    echo "Creating configuration directory"
    mkdir -p $PKG_CONF_DIR
fi

if [ ! -d "$PKG_FILE_DIR" ]; then
    echo "Creating descriptor directory"
    mkdir -p $PKG_FILE_DIR
fi

if [ ! -d "$PKG_ROOT_DIR" ]; then
    echo "Creating root directory"
    mkdir -p $PKG_ROOT_DIR
fi

if [ ! -d "$PKG_SOURCE_DIR" ]; then
    echo "Creating source file directory"
    mkdir -p $PKG_SOURCE_DIR
fi

if [ ! -d "$PKG_PACKAGE_DIR" ]; then
    echo "Creating binary package directory"
    mkdir -p $PKG_PACKAGE_DIR
fi

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

# Name: verbose <message>
# Desc: Print message on screen only when verbose is specified
verbose() {
    if [ "$VERBOSE" == "yes" ]; then
	echo "VERBOSE: $1"
    fi
}

# Name: pkg_find <package name>
# Desc: Find and return package descriptor location
pkg_find() {
    #echo `find $PKG_FILE_DIR -name "$1*.$PKG_FILE"`
    local -a TMP=($(find $PKG_FILE_DIR -name "$1*.$PKG_FILE"))
    if [[ ${#TMP[@]} > 1 ]]; then
	echo "Possible packages:" 1>&1
	for i in "${TMP[@]}"; do
	    echo "$i" 1>&1
	done
	echo "Using:" 2>&1
    fi
    echo "${TMP[0]}"
}

# Name: pkg_find_bin <package name>
# Desc: Find and return location for binary package
pkg_find_bin() {
    #echo `find $PKG_PACKAGE_DIR -name "$1*.$PKG_EXTENSION"`
    local -a TMP=($(find $PKG_PACKAGE_DIR -name "$1*.$PKG_EXTENSION"))
    if [[ ${#TMP[@]} > 1 ]]; then
	echo "Possible packages:" 1>&1
	for i in "${TMP[@]}"; do
	    echo "$i" 1>&1
	done
	echo "Using:" 2>&1
    fi
    echo "${TMP[0]}"
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
    if ! . $1 ; then
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

    if [ -z "$1" ]; then
	return 1
    fi

    # package name
    local PKG_NAME=`echo $1 | awk '{print $1;}'`
    # operator
    local PKG_OPER=`echo $1 | awk '{print $2;}'`
    # version need
    local PKG_NEED=`echo $1 | awk '{print $3;}'`

    # look for package
    if [ ! -d "$PKG_CONF_DIR/$PKG_NAME" ]; then
	return 1
    fi

    # current version
    local PKG_VERSION=`pkg_version $PKG_CONF_DIR/$PKG_NAME`

    ########

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
    local PKG_FILE_NAME="$1"

    if ! . $PKG_FILE_NAME ; then
	error "Could not find $PKG_FILE"
    fi

    # make sure that the needed variables exist
    if [ -z "$name" ]; then
	error "'name' not specified"
    fi
    if [ -z "$version" ]; then
	error "'version' not specified"
    fi
    if [ -z "$release" ]; then
	error "'release' not specified"
    fi

    # check to see if the package already exists
    if [ -e "$PKG_PACKAGE_DIR/$name-$version-$release.$PKG_EXTENSION" ]; then
	warn "Package already built ($name)"
	return 0
    fi

    # check dependancies
    for i in "${depends[@]}"; do
	if ! pkg_meets $i; then
	    if [ ! "$FORCE_NO_DEPS" == "yes" ]; then
		error "Dependancies not met ($i)"
	    else
		warn "Dependancies not met ($i). Ignoring."
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
	    warn "Conflicting packages ($i)"
	fi
    done

    # set up build environment
    # source/build directory
    local WORK=/tmp/gpack-`echo $PKG_FILE_NAME | sed -e 's|/.*/||'`-build
    local SRC=$WORK/src
    # package base directory
    local PKG_BASE=$WORK/pkg
    # package installation directory
    local PKG=$PKG_BASE/pkg

    # Trap
    trap "rm -rf $WORK && exit 'Interrupted build'" TERM HUP INT


    if [ -d "$WORK" ]; then
	warn "$WORK already exists. Removing"
	rm -rf $WORK
    fi

    mkdir -p $WORK
    mkdir -p $SRC
    mkdir -p $PKG_BASE
    mkdir -p $PKG

    # set up variable for CRUX compatibility
    local PKGMK_SOURCE_DIR=$PKG_SOURCE_DIR

    # make sure source is available
    verbose 'Getting source'
    for i in "${source[@]}"; do
	local SRC_FILE=`echo $i | sed 's|.*/||'`
	verbose "Checking for $SRC_FILE"
	if [ ! -e "$PKG_SOURCE_DIR/$SRC_FILE" ]; then
	    if ! (cd $PKG_SOURCE_DIR && wget $i); then
		error "Failed to retrieve source."
	    fi
	fi

	# copy/extract files
	(
	    cd $PKG_SOURCE_DIR &&
	    case `echo $SRC_FILE | sed -e 's/.*\.//'` in
		gz)
		    if (echo $SRC_FILE | grep 'tar'); then
			verbose "Extracting tar.gz"
			tar -xzf $SRC_FILE -C $SRC
		    else
			verbose "Extracting gz"
			(cp $SRC_FILE $SRC && cd $SRC && gunzip $SRC_FILE)
		    fi
		    ;;
		tgz)
		    verbose "Extracting tgz"
		    tar -xzf $SRC_FILE -C $SRC
		    ;;
		bz2)
		    if (echo $SRC_FILE | grep 'tar'); then
			verbose "Extracting tar.bz2"
			tar -xjf $SRC_FILE -C $SRC
		    else
			verbose "Extracting bz2"
			(cp $SRC_FILE $SRC && cd $SRC && bunzip2 $SRC_FILE)
		    fi
		    ;;
		zip)
		    verbose "Extracting zip"
		    unzip $SRC_FILE -d $SRC
		    ;;
		*)
		    verbose "Copying to $SRC"
		    cp $SRC_FILE $SRC
		    ;;
	    esac
	) || error "Extracting source"
    done

    # check checksum of source files
    verbose "Checking MD5 sums"
    local PKG_CHECKSUM=`echo $PKG_FILE_NAME | sed -e "s|$PKG_FILE|checksum|"`
    if [ -e "$PKG_CHECKSUM" ]; then
	verbose "Checking source integrity..."
	for i in "${source[@]}"; do
	    local SRC_FILE=`echo $i | sed 's|.*/||'`
	    local CHKSUM=`cat $PKG_CHECKSUM | grep $SRC_FILE | awk '{print $1;}'`
	    local FILE_CHKSUM=`(cd $PKG_SOURCE_DIR; md5sum $SRC_FILE) | awk '{print $1;}'`
	    if [ ! "$FILE_CHKSUM" == "$CHKSUM" ]; then
		echo "MD5 Mismatch ($SRC_FILE)"
		echo "Checksum:  $CHKSUM"
		echo "Should be: $FILE_CHKSUM"
		rm -rf $WORK
		exit 1
	    fi
	done
    else
	verbose "Generating checksum for source files..."
	for i in "${source[@]}"; do
	    local SRC_FILE=`echo $i | sed 's|.*/||'`
	    local CHKSUM=`md5sum $PKG_SOURCE_DIR/$SRC_FILE`
	    local MD5=`echo $CHKSUM | awk '{print $1;}'`
	    echo "$MD5 $SRC_FILE" >> $PKG_CHECKSUM
	done
    fi

    # build
    verbose "Build"
    if ! (cd $SRC && build) ; then
	rm -rf $WORK
	error "'build' failed"
    fi

    # build package
    verbose 'Creating package'

    verbose "$PKG_FILE_NAME $PKG_BASE"
    cp $PKG_FILE_NAME $PKG_BASE/$PKG_FILE

    # create package footprint
    verbose "Creating footprint"
    STAT_FORMAT='%b %a %U %G %n'
    for i in `find $PKG`; do
	stat -c "$STAT_FORMAT" $i | sed "s|$PKG||" >> $PKG_BASE/footprint
    done

    # create package format info
    echo "GPack $VERSION " `date` > $PKG_BASE/info

    # archive
    verbose "Creating package archive"
    if (cd $PKG_BASE && tar -czf $PKG_PACKAGE_DIR/$name-$version-$release.$PKG_EXTENSION *) ; then
	echo "Package created"
    else
	error "Failed to create package"
    fi

    verbose "Displaying footprint"
    cat $PKG_BASE/footprint

    verbose "Cleaning up"
    rm -rf $WORK

    echo "Package created successfully!"
}

# Name: pkg_install <package file>
# Desc: Installs package.
pkg_install() {
    local TMP=/tmp/gpack-`echo "$1" | sed -e 's|.*/\(.*\)-.*$|\1|'`
    if [ -d "$TMP" ]; then
	error "$TMP Package already exists -- either the package is being installed or an error has occurred. If there is an error, remove this directory"
    fi
    mkdir $TMP

    # extract package desc
    if ! tar -xzf $1 -C $TMP $PKG_FILE ; then
	error "Coult not extract package"
    fi

    (
        # trap signals
	trap "warn 'Cannot exit at this time.'" TERM HUP INT

	cd $TMP
	if ! . ./$PKG_FILE ; then
	    error "Invalid package format"
	fi

	if pkg_installed $name ; then
	    warn "Package already installed ($name)"
	    #if [ ! "$FORCE_OVERWRITE" == "yes" ]; then
		return 0
	    #fi
	fi

        # check dependancies
	for i in "${depends[@]}"; do
	    if ! pkg_meets $i; then
		if [ ! "$FORCE_NO_DEPS" == "yes" ]; then
		    error "Dependancies not met ($i)"
		else
		    warn "Dependancy not met ($i). Ignoring."
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

	# extract rest of archive
	if ! tar -xzf $1 -C $TMP ; then
	    error "Coult not extract package"
	fi

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

	# overwrite files?
	if [ "$INSTOK" == "1" ]; then
	    if [ ! "$FORCE_OVERWRITE" = "yes" ]; then
		error "Aborted install"
	    fi
	fi

	# install the files
	for i in `cat footprint | awk '{print $5;}'`; do
	    if [ -d "$TMP/pkg/$i" ]; then
	        # handly directories appropriately
		if [ ! -d "$PKG_ROOT_DIR/$i" ]; then
		    mkdir -p $PKG_ROOT_DIR/$i
		fi
	    else
		# TODO: keep may not always work
		if [ "$FORCE_KEEP" == "yes" ]; then
		    mv -u $TMP/pkg/$i $PKG_ROOT_DIR/$i
		else
		    mv $TMP/pkg/$i $PKG_ROOT_DIR/$i
		fi
	    fi
	done

	# create config entry
	mkdir $PKG_CONF_DIR/$name

	mv $PKG_FILE $PKG_CONF_DIR/$name/
	mv footprint $PKG_CONF_DIR/$name/

	# run post install
	post_install
    ) || (rm -rf $TMP && exit 1) || exit 1

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

	# trap
	trap "warn 'Cannot exit at this time.'" TERM HUP INT
	
	pre_remove
	
        # remove
	for i in `cat $PKG_CONF_DIR/$1/footprint | awk '{print $5;}' | sort -r`; do
	    if [ -d "$PKG_ROOT_DIR/$i" ]; then
		rmdir $PKG_ROOT_DIR/$i > /dev/null 2>&1
	    else
		verbose "Removing $i"
		rm -f $PKG_ROOT_DIR/$i > /dev/null 2>&1
	    fi
	done
	
	post_remove
	
        # remove installation info
	rm -rf $PKG_CONF_DIR/$1
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
    # avoid trying to install zero-length strings...
    [ -z "$1" ] && return 0

    (
	# clean up package environment (needed)
	name=''
	version=''
	group=''
	license=''
	depends=()
	optdeps=()
	conflicts=()
	source=()

	local TMP=/tmp/gpack-`echo "$1" | sed -e 's|.*/\(.*\)-.*$|\1|'`-dep
	if [ -d "$TMP" ]; then
	    warn "$TMP already exists"
	    return 0
	fi
	mkdir $TMP

	tar -xzf $1 -C $TMP $PKG_FILE

	if ! . $TMP/$PKG_FILE ; then
	    error "Could not find package config"
	fi
	
        # check dependancies
	for i in "${depends[@]}"; do
	    if ! pkg_meets $i; then
		if ! pkg_depinst `pkg_find_bin $i`; then
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
	
	local PKG_NAME="$PKG_PACKAGE_DIR/$name-$version-$release.$PKG_EXTENSION"
	if [ ! -e "$PKG_NAME" ]; then
	    if ! pkg_build $1 ; then
		error "Build failed"
	    fi
	fi
	pkg_install "$PKG_PACKAGE_DIR/$name-$version-$release.$PKG_EXTENSION"

	rm -rf $TMP
    ) || exit 1
    return 0
}
