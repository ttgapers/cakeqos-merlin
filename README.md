# CakeQOS-Merlin

## Pre-requisites
1. Currently only supports RT-86U & RT-AX88U running <a href="https://github.com/RMerl/asuswrt-merlin.ng">Merlin firmware</a> (384.xx and above)
2. Not recommended for connection up/down of 250Mbps or higher
3. Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables other stuff too)
4. Entware
5. USB Storage
6. jffs

## Tips
1. If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword. 
    https://man7.org/linux/man-pages/man8/tc-cake.8.html
2. Use 90-95% of your line speed as upload/download limits

## Install Example

<b>Important:>/b> If you installed an older version before, comment out or remove any cake entries in `/jffs/scripts/services-start` before proceeding.

1. Download and apply permissions:
> /usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos
2. Convert (just in case):
> dos2unix /jffs/scripts/cake-qos
3. Change for your router model (`ac86u` or `ax88u`):
> /jffs/scripts/cake-qos install **ac86u**
4. Change for your linespeed and any overhead (assuming 135Mbit download, 13Mbit upload, "docsis ack-filter" as optional extra parameters; speeds can also be specified in `Kbit` units):
> /jffs/scripts/cake-qos enable **135Mbit 13Mbit "docsis ack-filter"**
5. Reboot your router
6. Check System Log in web interface for **Cake Queue Management Starting**
7. (optional) To test, run the commands under **CLI** below and/or do a bufferbloat test on https://www.dslreports.com/speedtest

## Usage

> /jffs/scripts/cake-qos {install|enable|start|stop|disable}

(install, enable, and start have required parameters)

- install: download and install necessary cake-qos binaries
- enable:  start cake-qos and add to startup
- start:   start cake-qos
- stop:    stop cake-qos
- disable: stop cake-qos and remove from startup
    
## CLI

```
tc qdisc
tc -s qdisc show dev eth0 # for upload
tc -s qdisc show dev ifb9eth0 # for download
```
