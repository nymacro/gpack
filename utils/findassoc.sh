#!/bin/sh
# Find the packages associated with a certain file

if [[ $# < 1 ]]; then
    echo "usage:"
    echo "    $0 <file to find>"
    exit 1
fi

. ../gpack.conf

for i in `ls $PKG_CONF_DIR`; do
#    echo $i
    TMP=`cat $PKG_CONF_DIR/$i/footprint | grep "/$1$"`
    if [ ! "$TMP" == "" ]; then
        echo "FOUND: '$1' in package $i"
#        exit 0
    fi
done

echo "No packages on system contain that file"

exit 1

