# CakeQOS-Merlin

## Pre-requisites
1.  Currently supports ASUS HND models running [ASUSWRT-Merlin firmware](https://github.com/RMerl/asuswrt-merlin.ng) version 386.2 and above. Versions prior to 386.2 are supported on the legacy 386 branch or 384 branch. This script will automatically install the appropriate legacy version if your firmware does not support Cake natively.
2.  Not recommended for connection up/down of 250Mbps or higher. **Note:** Users with higher up/down connections have reported lower peaks but better stability and user experience overall and continue to use Cake.

## Tips
1.  If you use connections like ADSL, VDSL, Docsis, learn about the [overhead keyword](https://man7.org/linux/man-pages/man8/tc-cake.8.html#OVERHEAD_COMPENSATION_PARAMETERS) at the tc-cake man page.
2.  Read and understand the different [Priority Queue Parameters](https://man7.org/linux/man-pages/man8/tc-cake.8.html#PRIORITY_QUEUE_PARAMETERS) and [Flow Isolation Parameters](https://man7.org/linux/man-pages/man8/tc-cake.8.html#FLOW_ISOLATION_PARAMETERS).
3.  Use 90-95% of your line speed as upload/download limits

## Install Example

1.  For best results, uninstall the legacy CakeQOS-Merlin v1.0 script, then enable Cake in the router WebUI under Adaptive QoS / QoS (a reboot may be required).

2.  Run the installer:
	```sh
	mkdir -p /jffs/addons/cake-qos && /usr/sbin/curl -s "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/alpha/cake-qos.sh" -o "/jffs/addons/cake-qos/cake-qos" && chmod 755 /jffs/addons/cake-qos/cake-qos && sh /jffs/addons/cake-qos/cake-qos install
	```

3.  Configure your preferred settings in the WebUI under Adaptive QoS / CakeQOS-Merlin.

4.  To check that CakeQOS-Merlin is running, check the Cake Current Status section of the WebUI, and/or do a bufferbloat test on [DSLReports](https://www.dslreports.com/speedtest)

## Web Interface
[![Web Interface](https://i.imgur.com/W5nMiaf.png "Web Interface")](https://i.imgur.com/W5nMiaf.png "Web Interface")

## Usage

```sh
cake-qos {status|status download|status upload|update|install|uninstall}
```

-   status: check the current general status of cake-qos
-   status download: check the current download status of cake-qos
-   status upload: check the current upload status of cake-qos
-   update: update cake-qos installer (if any available)
-   install: download and install necessary cake-qos files
-   uninstall: remove from startup, and remove cake-qos files

## CLI
```sh
tc qdisc
tc qdisc show | grep root
tc -s qdisc show dev eth0 # for upload
tc -s qdisc show dev ifb4eth0 # for download
cake-qos status
```
## Uninstall/Remove

1.  SSH to the router and execute:
```sh
cake-qos uninstall
```
