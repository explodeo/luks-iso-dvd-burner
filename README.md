# Encrypt your DVDs with LUKS!
This is a script to create luks ISO files and burn them to dvds. This is essentially a glorified wrapper for `cryptsetup`
This uses aes256-xts-plain64 with sha512 hashing. Volumes currently only support 512-bit keyfile encryption. Passwords will be supported later. 

### Usage:
```bash
  $ sudo ./make-luks-iso.sh 'FILE_LIST' IMAGE_FILE [-h] [-k KEY_FILE] [-f]
```
#### Options:
- `-k`  KEYFILE must be 512bits in length. If omitted, a key will be generated
- `-f`  Causes FILE_LIST (in quotes) to be recognized as a path instead of a string
- `-h`  Print help/description

## Keyfiles
One way to make a keyfile in bash is shown below:
```bash 
$ dd bs=512 count=4 if=/dev/urandom of=./KEYFILE iflag=fullblock
```

## Required packages:
For creating the UDF filesystem: `sudo dnf -y install udftools`
You also need to install a burne like `dvd+rw-tools.x86_64` or `brasero`


## Sources
These Links helped me write this script:
- https://www.frederickding.com/posts/2017/08/luks-encrypted-dvd-bd-data-disc-guide-273316/
- https://gist.github.com/sowbug/c7f83140581fbe3e6a9b3ddf24891e77

## Mounting the ISO/DVD
1. make it accessible via a loopback device: 
```bash
  $ LO_DEVICE=losetup -f
  $ sudo losetup $LO_DEVICE image.iso #(or /dev/sr0)
```
2. Set up the device to be mapped as a logical volume: 
```bash
  $ sudo cryptsetup luksOpen [--key-file KEYFILE] $LO_DEVICE VOLUME_NAME
```
# 3. mount the device: 
```bash
    $ sudo mount /dev/mapper/VOLUME_NAME /mnt/MOUNTPOINT
```
## Copying files:
The command below will show you copying progress from source to destination:
```bash
$ rsync -ah --progress /path/to/source /path/to/destination
```

## Unounting the ISO/DVD
Basically do the steps above in reverse:
```bash
  $ sudo umount /mnt/MOUNTPOINT
  $ sudo cryptsetup luksClose VOLUME_NAME
  $ sudo losetup -d $LO_DEVICE
```
