# GPack Package Manager
# Package Manager Internals
# Aaron Marks 2005
# Fri Apr 29 20:24:06 UTC 2005

########################################################################
#
# Copyright 2005
# Aaron Marks
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

#later on Sat system gpack.conf will be in absolute dir
. ./gpack.conf

VERSION=0.8.0

# create directories if they dont exist
if [ ! -e "$PKGVFS" ]; then
    mkdir $PKGVFS
fi

if [ ! -e "$PKGINFO" ]; then
    mkdir $PKGINFO
fi

if [ ! -e "$PKGROOT" ]; then
    mkdir $PKGROOT
fi

#Filename for package build descriptor
PKGFILE=PKGBUILD

#Package extension
PKGEXT=gpack.tar.gz

#Return value for different functions
RETURN=

#Force overwrite existing files
FORCEOVERWRITE=0

#blank templates for post/pre install/remove
pre-install() {
    echo "Null pre-install" > /dev/null
}
post-install() {
    echo "Null post-install" > /dev/null
}
pre-remove() {
    echo "Null pre-remove" > /dev/null
}
post-remove() {
    echo "Null post-remove" > /dev/null
}

#Checks to see if package is installed
pkgInstalled() {
    echo "-- Checking if $1 is installed..."
    local PKGNAME=`echo $1 | sed 's|.*/||'`;
    if [ -d "$PKGINFO/$PKGNAME" ]; then
        return 1
    fi
    return 0
}

#Finds specified package
pkgFind() {
    echo "-- Looking for package '$1'"
    if [ -d "$PKGROOT/$1" ]; then
        RETURN=$PKGROOT/$1
        return 1
    else
        local FOUNDDIR=`find $PKGROOT -type d -name "$1"`
        if [ -d "$FOUNDDIR" ]; then
            RETURN=$FOUNDDIR
            return 1
        fi
        RETURN=
    fi
    return 0
}

#get package version
pkgVersion() {
    pkgFind $1
    if [ "$?" == "1" ]; then
        if [ -e "$RETURN/$PKGFILE" ]; then
            . $RETURN/$PKGFILE
        else
            echo "Error: Could not find associated $PKGFILE (version check)"
            exit 1
        fi
        RETURN=$version
        return 1
    fi
    return 0
}

#check if requirements are met
pkgCheckVersion() {
    local PACKAGE=`echo "$1" | awk '{ print $1; }'`
    local OPERATOR=`echo "$1" | awk '{ print $2; }'`
    local REQUIRED=`echo "$1" | awk '{ print $3; }'`

    #check version
    pkgVersion $PACKAGE
    if [ "$?" == "0" ]; then
        echo "Package not found!"
        exit 1
    fi

    local CURVERSION=$RETURN

    if [ ! "$REQUIRED" == "" ]; then
        if [ "$OPERATOR" == ">=" ]; then
            pkgVersion $PACKAGE
            if [[ $CURVERSION > $REQUIRED || $CURVERSION == $REQUIRED ]]
            then
                echo "Dependancy '$i' met"
                return 1
            else
                echo "Dependancy '$i' not met"
                return 0
            fi
        else
            if [ "$OPERATOR" == "<=" ]; then
                if [[ $CURVERSION < $REQUIRED ||
                    $CURVERSION == $REQUIRED ]]; then
                    echo "Dependancy '$i' met"
                    return 1
                else
                    echo "Dependancy '$i' not met (must be older)"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

#Checks to see if specified package is up to date
pkgUpToDate() {
    echo "-- Checking if package is up to date..."

    if [ -e "$1/$PKGFILE" ]; then
        . $1/$PKGFILE
    else
        echo "Error: Could not find a $PKGFILE (up to date checK)"
        exit 1
    fi

    if [ -e "$1/$name-$version.$PKGEXT" ]; then
        return 1
    else
        return 0
    fi
}

#Removes specified package
pkgRemove() {
    echo "-- Removing package $1"

    pkgInstalled $1
    if [ "$?" == "0" ]; then
        echo "Package is not installed!"
        return 0
    fi

    if [ -e "$PKGINFO/$1/$PKGFILE" ]; then
        . $PKGINFO/$1/$PKGFILE
    else
        echo "Error: Could not find $PKGFILE associated with $1! This isn't good."
        exit 1
    fi

    #run pre-remove
    pre-remove

    for i in `cat $PKGINFO/$1/footprint | sort -r`; do
#        echo $i
        if [ ! "$i" == "$PKGFILE" ]; then
            if [ -d "$PKGVFS/$i" ]; then
                rmdir $PKGVFS/$i > /dev/null 2>&1
            else
                rm -f $PKGVFS/$i
            fi
        fi
    done

    rm -Rf $PKGINFO/$1

    #run post-remove
    post-remove

    echo "-- Package removed!"
}

#Print package info
pkgInfo() {
    echo "Printing package description:"
    echo "name:    $name"
    echo "version: $version"
    echo "release: $release"
    echo "group:   $group"
    echo "license: $license"

    echo "dependancies:"
    for i in "${depends[@]}"; do
        echo "  $i"
    done
    echo

    echo "optional dependancies:"
    for i in "${optdeps[@]}"; do
        echo "  $i"
    done
    echo

    echo "source files:"
    for i in "${sources[@]}"; do
        echo "  $i"
    done
    echo
}

#Builds package
pkgBuild() {
    echo "-- Building package..."

    #set up working directory
    if [ -e "$1/work" ]; then
        rm -rf $1/work
    fi
    mkdir $1/work
    mkdir $1/work/src
    mkdir $1/work/pkg
    PKG=$1/work/pkg
    SRC=$1/work/src

    if [ -e "$1/$PKGFILE" ]; then
        . $1/$PKGFILE
    else
        echo "Error: Could not find $PKGFILE (build step)"
        exit 1
    fi

    pkgInfo

    # get sources
    cd $1
    for i in "${sources[@]}"; do
        local SRCFILE=`echo $i | sed 's|.*/||'`
        local EXT=`echo $SRCFILE | sed 's/.*\.//'`
        if [ ! -e "$SRCFILE" ]; then
            if ! wget $i ; then
                echo "ERROR: Could not download source file '$i'"
                exit 1
            fi
        fi

        case $EXT in
        gz)
            tar xzf $SRCFILE -C $SRC
            ;;
        bz2)
            tar xjf $SRCFILE -C $SRC
            ;;
        esac
    done
    cd $SRC

    #build package
    if build; then
        echo "Build Sucessful!"
        echo "Creating package..."

        #build package file
        cp $1/$PKGFILE $PKG

        local TMP=`pwd`
        cd $PKG
        if tar czvf $1/$name-$version.$PKGEXT  * ; then
            echo "Build package sucessfully!"
        else
            echo "Package build failed!"
        fi
        cd $TMP

        rm -Rf $1/work
        return 1
    else
        echo "Build failed!"

        #remove working dir
        rm -Rf $1/work

        return 0
    fi
}

#Installs the specified package
pkgInstall() {
    echo "-- Installing package..."

    pkgInstalled $1
    if [ "$?" == "1" ]; then
        echo "Package is already installed."
        return 0
    fi

    pkgFind $1
    if [ "$?" == "0" ]; then
        echo "Failed to install package '$1' -- could not find package."
        return 0
    fi
    local dir=$RETURN

    #check if package exists already
    pkgUpToDate $dir
    if [ "$?" == "0" ]; then
        #build package
        pkgBuild $dir

        if [ "$?" == "0" ]; then
            echo "FAILED TO BUILD PACKAGE IN $dir"
            return 0
        fi
    else
        echo "Package $1 is up to date"
    fi

    if [ -e "$dir/$PKGFILE" ]; then
        . $dir/$PKGFILE
    else
        echo "Error: Could not find $PKGFILE (install step)"
        exit 1
    fi

    #tell about dependancies
    echo "-- Dependancies:"
    for i in "${depends[@]}"; do
        pkgCheckVersion "$i"
        if [ "$?" == "0" ]; then
            echo "Dependancies not met"
            exit 1
        fi

        pkgInstalled $i
        if [ "$?" == "0" ]; then
            echo "WARNING! Dependancy '$i' not installed!"
        fi
    done

    echo "-- Optional Dependancies:"
    for i in "${optdeps[@]}"; do
        pkgInstalled $i
        if [ "$?" == "0" ]; then
            echo "WARNING! Optional dependancy '$i' not installed!"
        fi
    done

    #install it
    pkgDoInstall $dir/$name-$version.$PKGEXT

    return 1
}

#installs actual package
pkgDoInstall() {
    #Temporary directory for package
    PKGTMP=/tmp/`date +%s`

    #install
    mkdir $PKGTMP
    if tar zxvf $1 -C $PKGTMP > $PKGTMP/footprint
    then
        if [ -e "$PKGTMP/$PKGFILE" ]; then
            . $PKGTMP/$PKGFILE
        else
            echo "Error: gpack.tar.gz does not seem to be valid. Could not find $PKGFILE"
            rm -Rf $PKGTMP
            exit 1
        fi

        # make sure package isn't already installed
        pkgInstalled $name
        if [ "$?" == "1" ]; then
            echo "Package is already installed."
            rm -Rf $PKGTMP
            return 0
        fi

        #look for conflicts in existing file system
        local HASFILES=0
        for i in `cat $PKGTMP/footprint`; do
            local ISDIR=`echo $i | sed 's|.*/||'`
#            echo $i
            if [ ! "$ISDIR" == "" ]; then
                if [ -e "$PKGVFS/$i" ]; then
                    echo "File $i already exists. Aborting"
                    HASFILES=1
                fi
            fi
        done
        if [ "$HASFILES" == "1" ]; then
            echo "-- Package install failed."
            exit 1
        fi

        #run pre install
        pre-install

        # set up installed info
        mkdir $PKGINFO/$name
        mv $PKGTMP/$PKGFILE $PKGINFO/$name
        mv $PKGTMP/footprint $PKGINFO/$name

        #install files
#        cp -R $PKGTMP/* $PKGVFS

        for i in `cat $PKGINFO/$name/footprint`; do
            local ISDIR=`echo $i | sed 's|.*/||'`
#            echo $i
            if [ ! "$i" == "$PKGFILE" ]; then
                if [ ! "$ISDIR" == "" ]; then
                    mv $PKGTMP/$i $PKGVFS/$i
                else
                    if [ ! -d "$i" ]; then
                        mkdir $PKGVFS/$i
                    fi
                fi
            fi
        done

        #run post install
        post-install

    else
        echo "An error occurred while trying to install package '$name'"
        rm -Rf $PKGINFO/$name
        rm -Rf $PKGTMP
        return 0
    fi
    rm -Rf $PKGTMP
}

#install with dependancies
pkgDepInstall() {
    local PACKAGE=`echo "$i" | awk '{ print $1; }'`
    local OPERATOR=`echo "$i" | awk '{ print $2; }'`
    local REQUIRED=`echo "$i" | awk '{ print $3; }'`

    pkgFind $PACKAGE
    if [ "$?" == "0" ]; then
        echo "Failed to install package '$1' -- could not find package."
        return 0
    fi
    local dir=$RETURN

    pkgInstalled $1
    if [ "$?" == "1" ]; then
        echo "Package '$1' already installed"
        exit 1
    fi

    . $dir/$PKGFILE

    echo "-- Package group: $group"

    #install dependancies
    echo "-- Dependancies:"
    for i in "${depends[@]}"; do
#        pkgFind $i
#        if [ "$?" == "0" ]; then
#            echo "    $i - PACKAGE NOT FOUND"
#            exit 1
#        else
            #install dep
            pkgInstalled $PACKAGE
            if [ "$?" == "0" ]; then
                pkgDepInstall $PACKAGE
                if [ "$?" == "0" ]; then
                    echo "Could not install $PACKAGE"
                    exit 1
                fi
            else
                pkgCheckVersion "$i"
                if [ "$?" == "0" ]; then
                    echo "Dependancies not met"
                    exit 1
                fi
                #
            fi
#        fi
    done

    #tell about optional dependancies
    echo "-- Optional Dependancies:"
    for i in "${optdeps[@]}"; do
        pkgInstalled $i
        if [ "$?" == "0" ]; then
            echo "WARNING! Optional dependancy '$i' not installed!"
        fi
    done

    pkgInstall $1
    return 1
}

