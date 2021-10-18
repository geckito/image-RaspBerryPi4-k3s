root_device=$2
loop_name=$(basename $root_device | cut -f 1-2 -d'p')

# mount root part
root=$(mktemp -d /tmp/rootmount-XXX)
mount /dev/mapper/${loop_name}p5 $root || exit 1

# delete what you don't need
rm -f $root/usr/bin/

# umount root part
umount --lazy $root && rmdir $root

