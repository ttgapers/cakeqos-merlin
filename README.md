# CakeQOS-Merlin

## Pre-requisites
1. Currently only supports RT-86U & RT-AX88U running Merlin firmware
2. Not recommended for connection up/down of 250Mbps or higher
3. Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables others stuff too)
4. Entware
5. USB Storage
6. jffs

## Tips
1. If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword. 
    https://man7.org/linux/man-pages/man8/tc-cake.8.html
2. Use 90-95% of your line speed as upload/download limits

## Install Example
1. Download and apply permissions:
> /usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos
2. Convert (just in case):
> dos2unix /jffs/scripts/cake-qos
3. Change for your router model (`ac86u` or `ax88u`):
> /jffs/scripts/cake-qos install **ac86u**
4. Change for your linespeed and any overhead (assuming 135Mbit download, 13Mbit upload, "docsis ack-filter" as optional extra parameters; speeds can also be specified in `Kbit` units):
> /jffs/scripts/cake-qos enable **135Mbit 13Mbit "docsis ack-filter"**

## Usage

> /jffs/scripts/cake-qos {install|enable|start|startnow|stop|disable}

(install, enable, start, and startnow have required parameters)
    
## CLI

```
tc qdisc
tc -s qdisc show dev eth0 (for upload)
tc -s qdisc show dev ifb9eth0 (for download)
```
