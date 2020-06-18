# CakeQOS-Merlin
Pre-reqs
    Not recommended for connection up/down of 250Mbps or higher
    Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables others stuff too)
    Entware
    USB Storage
    jffs

Tips
If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword. https://man7.org/linux/man-pages/man8/tc-cake.8.html
Use 90-95% of your line speed as upload/download limits

Install Example
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos /jffs/scripts/cake-qos install ac86u /jffs/scripts/cake-qos enable 135Mbit 13Mbit "docsis ack-filter"

CLI
    tc qdisc
    tc -s qdisc show dev eth0 (for upload)
    tc -s qdisc show dev ifb9eth0 (for download)
