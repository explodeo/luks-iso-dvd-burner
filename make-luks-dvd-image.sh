#!/bin/bash

# check if root first
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

Help()
{
   echo "Script: $(pwd)/make-luks-iso.sh"
   echo "This script is used to build LUKS ISO images for burning to a CD/DVD/BluRay."
   echo "The encryption used is aes-xts-plain64. SHA2-512 is used for hash derivation."
   echo "Usage: ./make-luks-iso.sh 'FILE_LIST' IMAGE_FILE [-h] [-k KEY_FILE] [-f]"
   echo "Options:"
   echo "  -k  KEYFILE must be 512bits in length. If omitted, a key will be generated"
   echo "  -f Causes FILE_LIST (in quotes) to be recognized as a path instead of a string"
   echo "  -h  Print this Help"
   echo ''
}

LO_ADAPTER=`losetup -f`

IMAGE_SIZE=0

FILE_LIST="$1"
IMAGE_FILE="$2"
shift 2

while getopts "hfk:" option; do
   case $option in
        h) # Help message
            Help
            exit;;
        f) # Installing containers
            USE_FILE_PATH=1
            IMAGE_SIZE=`cat $FILE_LIST | while read file; do du -b "$file"; done | awk '{totalsize+=$1} END {print totalsize}'`
            ;;
        k) # Rebuild codebook
            KEY_FILE=${OPTARG}
            if [[ ! -f $KEY_FILE ]]; then 
                echo "ERROR: File '$KEY_FILE' cannot be read/found."
                exit
            fi
            ;;
        \?) # Invalid option
            exit;;
   esac
done

# if a keyfile is not specified, create one 512-bit (64-Byte) keyfile
if [ -z "$KEY_FILE" ]; then
    KEY_FILE=./$(echo $RANDOM | md5sum | head -c 20)
    head -c 64 /dev/urandom > ./$KEY_FILE
fi

VOLUME_NAME=$(echo $RANDOM | md5sum | head -c 20)
TEMP_MOUNTPOINT=$(echo $RANDOM | md5sum | head -c 20)

# set image size to at least the size of a CD-ROM
IMAGE_SIZE=$(( $IMAGE_SIZE > 500000000 ? $IMAGE_SIZE+200000000 : 700000000)) #200 MB UDF+LUKS Header

echo $FILE_LIST $IMAGE_FILE $USE_FILE_PATH $IMAGE_SIZE $KEY_FILE $LO_ADAPTER

# make a disk image of specified size
truncate -s $IMAGE_SIZE $IMAGE_FILE

# generate LUKS-encrypted UDF Filesystem for the image
losetup $LO_ADAPTER $IMAGE_FILE
cryptsetup luksFormat -d $KEY_FILE -c aes-xts-plain64 -s 512 -h sha512 --use-urandom --iter-time 5000 $LO_ADAPTER
cryptsetup luksOpen --key-file $KEY_FILE $LO_ADAPTER $VOLUME_NAME
mkudffs /dev/mapper/$VOLUME_NAME

# mount the UDF image filesystem
mkdir /media/$TEMP_MOUNTPOINT
mount -t udf /dev/mapper/$VOLUME_NAME /media/$TEMP_MOUNTPOINT

# copy files using listfile or string
if [ -z $USE_FILE_PATH ]; then
    for file in $(echo $FILE_LIST); do cp -r "$file" "/media/$TEMP_MOUNTPOINT/"; done
else
    for file in $(cat $FILE_LIST); do cp -r "$file" "/media/$TEMP_MOUNTPOINT/"; done
fi

# close the device and image
umount /dev/mapper/$VOLUME_NAME

echo "[!] LUKS partition information:"
cryptsetup luksDump $LO_ADAPTER 
cryptsetup luksClose $VOLUME_NAME;
losetup -d $LO_ADAPTER;

# remove the temp mountpoint directory
rmdir /media/$TEMP_MOUNTPOINT

echo "[!] The keyfile for $IMAGE_FILE is at ./$KEY_FILE"
echo 'DONE!'

