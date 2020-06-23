# CakeQOS-Merlin

## Pre-requisites
1.  Currently only supports RT-86U & RT-AX88U running [Melin firmware](https://github.com/RMerl/asuswrt-merlin.ng) (384.xx and above)
2.  Not recommended for connection up/down of 250Mbps or higher. **Note:** Users with higher up/down connections have reported lower peaks but better stability and user experience overall and continue to use Cake.
3.  Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables other stuff too)
4.  Entware
5.  USB Storage
6.  jffs

## Tips
1.  If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword.
    
    [https://man7.org/linux/man-pages/man8/tc-cake.8.html](https://man7.org/linux/man-pages/man8/tc-cake.8.html)
    
2.  If you want to understand and change Priority Queue Parameters.
    
    [https://man7.org/linux/man-pages/man8/tc-cake.8.html#PRIORITY_QUEUE_PARAMETERS](https://man7.org/linux/man-pages/man8/tc-cake.8.html#PRIORITY_QUEUE_PARAMETERS)
    
3.  Use 90-95% of your line speed as upload/download limits

## Install Example

**Important:** If you installed an older version before, comment out or remove any cake entries in `/jffs/scripts/services-start` before proceeding.

1.  Download and apply permissions:
    ```sh
    /usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos
    ```
2.  Run the start command with the params you want (installer will detect your router model). If you receive any errors (e.g. libnl-tiny package size mismatch) please ensure your Entware instance is up-to-date.

    Change for your linespeed and any overhead (assuming 135Mbit download, 13Mbit upload, "besteffort docsis ack-filter" as optional extra parameters; speeds can also be specified in `Kbit` units):
    ```sh
    /jffs/scripts/cake-qos start **135Mbit 13Mbit "besteffort docsis ack-filter"**
    ```
3.  Reboot your router

4.  Check System Log entries in web interface for **CakeQOS-Merlin**

5.  To check that CakeQOS-Merlin is running, run `cake-qos status` and/or do a bufferbloat test on [dslreports](https://www.dslreports.com/speedtest)

## Usage

```sh
cake-qos {install|update|start|status|stop|disable|uninstall}
```
(start has required parameters)

-   install: only download and install necessary cake-qos binaries
-   update: update cake-qos binaries and installer (if any available)
-   start:   configure and start cake-qos
-   status:   check the current status of cake-qos
-   stop:    stop cake-qos
-   disable: stop cake-qos and remove from startup
-   uninstall: stop cake-qos, remove from startup, and remove cake binaries

**Note:** defaults to `besteffort` priority queue if none specified in `start` option.

## CLI
```sh
tc qdisc
tc qdisc show | grep root
tc -s qdisc show dev eth0 # for upload
tc -s qdisc show dev ifb9eth0 # for download
cake-qos status
```
## Uninstall/Remove

1.  SSH to the router and execute:
```sh
cake-qos uninstall
```
