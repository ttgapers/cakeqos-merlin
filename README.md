# CakeQOS-Merlin
<b>Pre-reqs</b><br />
    Currently only supports RT-86U & RT-AX88U running Merlin firmware<br />
    Not recommended for connection up/down of 250Mbps or higher<br />
    Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables others stuff too)<br />
    Entware<br />
    USB Storage<br />
    jffs<br />
<br />
<b>Tips</b><br />
If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword. https://man7.org/linux/man-pages/man8/tc-cake.8.html<br />
Use 90-95% of your line speed as upload/download limits<br />
<br />
<b>Install Example</b><br />
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/ttgapers/cakeqos-merlin/master/cake-qos.sh" -o "/jffs/scripts/cake-qos" && chmod 0755 /jffs/scripts/cake-qos<br />
/jffs/scripts/cake-qos install <b>ac86u</b><br />
/jffs/scripts/cake-qos enable <b>135</b>Mbit <b>13</b>Mbit <b>"docsis ack-filter"</b>
<br />
<b>CLI</b><br />
    tc qdisc<br />
    tc -s qdisc show dev eth0 (for upload)<br />
    tc -s qdisc show dev ifb9eth0 (for download)<br />
