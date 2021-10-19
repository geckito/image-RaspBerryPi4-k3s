
Geckito k3s node example
========================

This example builds is producing a k3s node image for a Raspberry Pi 4.

k3s gets installed by execute the installer script as provided by
get.k3s.io server. You need to enable network for building therefore.

Be aware that this is breaking the sandbox and will make your build
not reproducible!

Build it by executing:

```shell
 # pbuild --vm-type=kvm --vm-network
```

Deploy the image using 

```shell
 # dd_rescue _build.aarch64/k3s-image/*.raw /dev/YOUR_SD_CARD
```

You can setup network and sshd via usual Geckito procedure:

```shell
 # mount /dev/mmcblk0p2 /mnt
 # less /mnt/boot/README.txt & following
 # umount /mnt
```

