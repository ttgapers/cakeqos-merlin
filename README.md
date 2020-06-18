# cakeqos-merlin
Pre-reqs
    Not recommended for connection up/down of 250Mbps or higher
    Disable QoS (any) - probably best to go to Admin/Privacy and "Withdraw" to be sure (note disables others stuff too)
    Entware
    USB Storage
    jffs

Tips
If you use connections like ADSL, VDSL, Docsis, learn about the overhead keyword. https://man7.org/linux/man-pages/man8/tc-cake.8.html
See: https://www.reddit.com/r/linux/comments/fvi267/psa_sqm_cake_nat_and_bufferbloat_tuning/ 
Use 95% of your line speed as upload/download limits

Note:
eth0 for upload, ifb9eth0 for download.
Kbit or Mbit both are ok. e.g 800Kbps upload and 10Mbps download.

Edit the lines in the above code block to suit along with any tweaks based on the Tips above based on connection type ADSL, Docsis etc.

    /opt/sbin/tc qdisc replace dev eth0 root cake bandwidth 800Kbit besteffort nat
    /opt/sbin/tc qdisc add dev ifb9eth0 root cake bandwidth 10Mbit besteffort nat ingress wash

6. nano /jffs/scripts/services-start
7. Add sh /jffs/scripts/cake-qos-start.sh start
8. nano /jffs/script/services-stop
9. Add /jffs/scripts/cake-qos-start.sh stop
10. chmod +x /jffs/scripts/cake-qos-start.sh
11. Start Cake QoS: sh /jffs/scripts/cake-qos-start.sh start OR to stop sh /jffs/scripts/cake-qos-start.sh stop
12. Validate/test

    tc qdisc
    tc -s qdisc show dev eth0 (for upload)
    tc -s qdisc show dev ifb9eth0 (for download)
