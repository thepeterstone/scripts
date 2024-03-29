#!/bin/sh
#------------------------------------------------------------------------------
# File: fw_laptop
# Author: Uwe Hermann <uwe@hermann-uwe.de>
# URL: http://www.hermann-uwe.de/files/fw_laptop
# License: GNU GPL (version 2, or any later version).
# $Id: fw_laptop 529 2006-06-10 15:11:40Z uh1763 $
#------------------------------------------------------------------------------

# A firewall script intended to be used on workstations / laptops. It basically
# blocks all incoming traffic and only allows minimal outgoing traffic.
# It helps to mitigate certains attacks, misconfigurations of local daemons,
# misbehaving local users or applications, and can prevent untrusted
# applications from "phoning home", among other things.

# Note: This is work in progress! Any comments and suggestions are welcome!

# Thanks for comments and suggestions:
#   * Jean Christophe Andr� <jean-christophe.andre@auf.org>
#   * Ryan Giobbi <rgiobbi@gmail.com>
#   * Pascal Hambourg <pascal.mail@plouf.fr.eu.org>


#------------------------------------------------------------------------------
# Configuration.
#------------------------------------------------------------------------------

# For debugging use iptables -v.
IPTABLES="/sbin/iptables"
IP6TABLES="/sbin/ip6tables"
MODPROBE="/sbin/modprobe"
RMMOD="/sbin/rmmod"
ARP="/usr/sbin/arp"

# Logging options.
# Note: We use --log-level debug, so that the messages are not output
# to all virtual consoles (which would be quite annoying).
# Alternative: Start klogd with -c 4 (e.g. by setting KLOGD="-c 4" in the
# /etc/init.d/klogd startup-script.
LOG="LOG --log-level debug --log-tcp-sequence --log-tcp-options"
LOG="$LOG --log-ip-options"

# Defaults for rate limiting (to prevent DoS attacks and excessive logging).
# TODO: What is a good value for --limit and --limit-burst?
# TODO: Test rate limiting.
RLIMIT="-m limit --limit 3/s --limit-burst 8"

# Unprivileged ports.
PHIGH="1024:65535"

# Common SSH source ports.
PSSH="1000:1023"

# Load required kernel modules (if automatic module loading is disabled).
$MODPROBE ip_conntrack_ftp
$MODPROBE ip_conntrack_irc


#------------------------------------------------------------------------------
# Mitigate ARP spoofing/poisoning and similar attacks.
# For details see:
#   * http://en.wikipedia.org/wiki/ARP_spoofing
#   * http://www.grc.com/nat/arp.htm
#------------------------------------------------------------------------------

# Hardcode static ARP cache entries here (e.g. for the network gateway).
# $ARP -s IP-ADDRESS MAC-ADDRESS


#------------------------------------------------------------------------------
# Kernel configuration.
# For details see:
#   * http://www.securityfocus.com/infocus/1711
#   * http://www.linuxgazette.com/issue77/lechnyr.html
#   * http://ipsysctl-tutorial.frozentux.net/chunkyhtml/index.html
#   * /usr/src/linux/Documentation/filesystems/proc.txt
#   * /usr/src/linux/Documentation/networking/ip-sysctl.txt
#------------------------------------------------------------------------------

# Disable IP forwarding.
# Note: We turn this on and off to reset all settings to their defaults.
echo 1 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/ip_forward

# Enable IP spoofing protection (i.e. source address verification).
# Note: This is special, as it seems to only be enabled if you set
# */all/rp_filter AND */eth0/rp_filter (for example) to 1! Setting only
# */all/rp_filter alone does _not_ suffice, which is pretty counter-intuitive.
for i in /proc/sys/net/ipv4/conf/*/rp_filter; do echo 1 > $i; done

# Protect against SYN flood attacks (see http://cr.yp.to/syncookies.html).
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Ignore all incoming ICMP echo requests (i.e. disable ping).
# Usually not a good idea, as some protocols and users need/want this.
# echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_all

# Ignore ICMP echo requests to broadcast/multicast addresses. We do not
# want to participate in smurf (and similar) DoS attacks.
# For details see: http://en.wikipedia.org/wiki/Smurf_attack.
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Log packets with impossible addresses.
for i in /proc/sys/net/ipv4/conf/*/log_martians; do echo 1 > $i; done

# Don't log invalid responses to broadcast frames, they just clutter the logs.
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Don't accept or send ICMP redirects.
for i in /proc/sys/net/ipv4/conf/*/accept_redirects; do echo 0 > $i; done
for i in /proc/sys/net/ipv4/conf/*/send_redirects; do echo 0 > $i; done

# Don't accept source routed packets.
for i in /proc/sys/net/ipv4/conf/*/accept_source_route; do echo 0 > $i; done

# Disable multicast routing. Should not be needed, usually.
# TODO: This throws an "Operation not permitted" error. Why?
# for i in /proc/sys/net/ipv4/conf/*/mc_forwarding; do echo 0 > $i; done

# Disable proxy_arp. Should not be needed, usually.
for i in /proc/sys/net/ipv4/conf/*/proxy_arp; do echo 0 > $i; done

# Enable secure redirects, i.e. only accept ICMP redirects for gateways
# listed in the default gateway list. Helps against MITM attacks.
for i in /proc/sys/net/ipv4/conf/*/secure_redirects; do echo 1 > $i; done

# Disable bootp_relay. Should not be needed, usually.
for i in /proc/sys/net/ipv4/conf/*/bootp_relay; do echo 0 > $i; done

# TODO: These may mitigate ARP poisoning attacks?
# /proc/sys/net/ipv4/neigh/*/locktime
# /proc/sys/net/ipv4/neigh/*/gc_stale_time

# TODO: Check rest of /usr/src/linux/Documentation/networking/ip-sysctl.txt.
# Are there any security-relevant options I missed? Check especially:
# icmp_ratelimit, icmp_ratemask, icmp_errors_use_inbound_ifaddr, arp_*.


#------------------------------------------------------------------------------
# Default policies.
#------------------------------------------------------------------------------

# Drop everything by default.
# Note: The default policies are set _before_ flushing the chains, to prevent
# a short timespan between flushing the chains and setting policies where
# any traffic would be allowed.
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP
$IPTABLES -P OUTPUT DROP

# Set the nat/mangle/raw tables' chains to ACCEPT (we don't use them).
# Packets will simply pass through these tables unchanged.
# TODO: What happens if the modules aren't loaded?
$IPTABLES -t nat -P PREROUTING ACCEPT
$IPTABLES -t nat -P OUTPUT ACCEPT
$IPTABLES -t nat -P POSTROUTING ACCEPT

$IPTABLES -t mangle -P PREROUTING ACCEPT
$IPTABLES -t mangle -P INPUT ACCEPT
$IPTABLES -t mangle -P FORWARD ACCEPT
$IPTABLES -t mangle -P OUTPUT ACCEPT
$IPTABLES -t mangle -P POSTROUTING ACCEPT

# TODO: Correct? Remove this?
# $IPTABLES -t raw -P PREROUTING ACCEPT
# $IPTABLES -t raw -P OUTPUT ACCEPT


#------------------------------------------------------------------------------
# Cleanup.
#------------------------------------------------------------------------------

# Delete all rules.
$IPTABLES -F
$IPTABLES -t nat -F
$IPTABLES -t mangle -F

# Delete all (non-builtin) user-defined chains.
$IPTABLES -X
$IPTABLES -t nat -X
$IPTABLES -t mangle -X

# Zero all packet and byte counters.
$IPTABLES -Z
$IPTABLES -t nat -Z
$IPTABLES -t mangle -Z


#------------------------------------------------------------------------------
# Completely disable IPv6.
#------------------------------------------------------------------------------

# Block all IPv6 traffic, otherwise the firewall might be circumvented by an
# attacker who simply sends IPv6 traffic instead of IPv4 traffic.
# Note: The safest way to prevent IPv6 traffic is to not enable support for
# IPv6 in the kernel in the first place (neither built-in nor as a module).

# If the ip6tables command is available, try to block all IPv6 traffic.
if test -x $IP6TABLES; then
  # Set the default policies (drop everything).
  $IP6TABLES -P INPUT DROP 2>/dev/null
  $IP6TABLES -P FORWARD DROP 2>/dev/null
  $IP6TABLES -P OUTPUT DROP 2>/dev/null

  # The mangle table can pass everything through unaltered (we don't use it).
  $IP6TABLES -t mangle -P PREROUTING ACCEPT 2>/dev/null
  $IP6TABLES -t mangle -P INPUT ACCEPT 2>/dev/null
  $IP6TABLES -t mangle -P FORWARD ACCEPT 2>/dev/null
  $IP6TABLES -t mangle -P OUTPUT ACCEPT 2>/dev/null
  $IP6TABLES -t mangle -P POSTROUTING ACCEPT 2>/dev/null

  # Delete all rules.
  $IP6TABLES -F 2>/dev/null
  $IP6TABLES -t mangle -F 2>/dev/null

  # Delete all (non-builtin) user-defined chains.
  $IP6TABLES -X 2>/dev/null
  $IP6TABLES -t mangle -X 2>/dev/null

  # Zero all packet and byte counters.
  $IP6TABLES -Z 2>/dev/null
  $IP6TABLES -t mangle -Z 2>/dev/null
fi


#------------------------------------------------------------------------------
# Custom user-defined chains.
#------------------------------------------------------------------------------

# LOG packets, then ACCEPT them.
$IPTABLES -N ACCEPTLOG
$IPTABLES -A ACCEPTLOG -j $LOG $RLIMIT --log-prefix "ACCEPT "
$IPTABLES -A ACCEPTLOG -j ACCEPT

# LOG packets, then DROP them.
$IPTABLES -N DROPLOG
$IPTABLES -A DROPLOG -j $LOG $RLIMIT --log-prefix "DROP "
$IPTABLES -A DROPLOG -j DROP

# LOG packets, then REJECT them. TCP packets are rejected with a TCP reset.
$IPTABLES -N REJECTLOG
$IPTABLES -A REJECTLOG -j $LOG $RLIMIT --log-prefix "REJECT "
$IPTABLES -A REJECTLOG -p tcp -j REJECT --reject-with tcp-reset
$IPTABLES -A REJECTLOG -j REJECT

# A custom chain which only allows minimal (RELATED) ICMP types
# (destination-unreachable, time-exceeded, and parameter-problem).
# TODO: Rate-limit this traffic?
# TODO: Allow fragmentation-needed?
# TODO: Test.
$IPTABLES -N RELATED_ICMP 
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type destination-unreachable -j ACCEPT
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type time-exceeded -j ACCEPT
$IPTABLES -A RELATED_ICMP -p icmp --icmp-type parameter-problem -j ACCEPT
$IPTABLES -A RELATED_ICMP -j DROPLOG


#------------------------------------------------------------------------------
# Only allow the minimally required/recommended parts of ICMP. Block the rest.
# For details see:
#   * http://tools.ietf.org/html/792
#   * http://tools.ietf.org/html/1122
#   * http://www.iana.org/assignments/icmp-parameters
#   * http://www.daemon.be/maarten/icmpfilter.html
#------------------------------------------------------------------------------

# Note: Be careful if you're using kernels older than 2.4.29. Some locally
# generated ICMP error types (going through OUTPUT) are erroneously tagged
# as INVALID (instead of RELATED).
# Details: http://lists.debian.org/debian-firewall/2006/05/msg00051.html.

# TODO: This section needs a lot of testing!

# First, drop all fragmented ICMP packets (almost always malicious).
$IPTABLES -A INPUT -p icmp --fragment -j DROPLOG
$IPTABLES -A OUTPUT -p icmp --fragment -j DROPLOG
$IPTABLES -A FORWARD -p icmp --fragment -j DROPLOG

# Allow all ESTABLISHED ICMP traffic.
# TODO: Tighten this some more?
$IPTABLES -A INPUT -p icmp -m state --state ESTABLISHED -j ACCEPT $RLIMIT
$IPTABLES -A OUTPUT -p icmp -m state --state ESTABLISHED -j ACCEPT $RLIMIT

# Allow some parts of the RELATED ICMP traffic, block the rest.
# TODO: FORWARD?
$IPTABLES -A INPUT -p icmp -m state --state RELATED -j RELATED_ICMP $RLIMIT
$IPTABLES -A OUTPUT -p icmp -m state --state RELATED -j RELATED_ICMP $RLIMIT

# Allow incoming ICMP echo requests (ping), but only rate-limited.
$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT $RLIMIT

# Allow outgoing ICMP echo requests (ping), but only rate-limited.
# TODO: Really do rate limiting here?
$IPTABLES -A OUTPUT -p icmp --icmp-type echo-request -j ACCEPT $RLIMIT

# Drop any other ICMP traffic.
$IPTABLES -A INPUT -p icmp -j DROPLOG
$IPTABLES -A OUTPUT -p icmp -j DROPLOG
$IPTABLES -A FORWARD -p icmp -j DROPLOG


#------------------------------------------------------------------------------
# Selectively allow certain special types of traffic.
#------------------------------------------------------------------------------

# Allow all incoming and outgoing connections on the loopback interface.
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

# Allow incoming connections related to existing allowed connections.
$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing connections related to existing allowed connections.
$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Uncomment this (and comment the above line) to allow all outgoing
# connections (except for INVALID ones).
# $IPTABLES -A OUTPUT -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
 
# TODO: Read Securing Debian Manual's "Disabling weak-end hosts issues".
# For details see:
#   * http://www.debian.org/doc/manuals/securing-debian-howto/
#   * ftp://ftp.isi.edu/in-notes/rfc1122.txt

# TODO: Split the ESTABLISHED,RELATED rules by state, protocol, type?


#------------------------------------------------------------------------------
# Miscellaneous.
#------------------------------------------------------------------------------

# Drop SMB/CIFS, and related Windows traffic without logging. We don't care.
# TODO: I think not all of these use TCP _and_ UDP. Tighten the rules!
$IPTABLES -A INPUT -p tcp -m multiport \
          --dports 135,137,138,139,445,1433,1434 -j DROP
$IPTABLES -A INPUT -p udp -m multiport \
          --dports 135,137,138,139,445,1433,1434 -j DROP

# Explicitly drop invalid incoming traffic (use DROPLOG if you want logging).
$IPTABLES -A INPUT -m state --state INVALID -j DROP

# Drop invalid outgoing traffic, too.
# Note: This may prevent you from performing certain scans. Also, see above
# comment about ICMP packets being erroneously marked as INVALID instead of
# RELATED in kernels older than 2.4.29. Remove this rule if needed.
#$IPTABLES -A OUTPUT -m state --state INVALID -j DROP

# This is not needed, as we use policy DROP for FORWARD, and we disabled
# ip_forward anyways. However, if we would use NAT, INVALID packets would
# bypass our rules, so we block them explicitly here, just in case.
$IPTABLES -A FORWARD -m state --state INVALID -j DROP

# Hinder portscanners a bit.
$IPTABLES -A INPUT -m state --state NEW -p tcp --tcp-flags ALL ALL -j DROP
$IPTABLES -A INPUT -m state --state NEW -p tcp --tcp-flags ALL NONE -j DROP

# TODO: Some more anti-spoofing rules? For example:
# TODO: Test.
# $IPTABLES -A INPUT -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
# $IPTABLES -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
# $IPTABLES -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP

# TODO: Block known-bad IPs (see http://www.dshield.org/top10.php).
# $IPTABLES -A INPUT -s INSERT-BAD-IP-HERE -j DROPLOG


#------------------------------------------------------------------------------
# Drop any traffic from IANA-reserved IPs.
# Note: You could easily block valid traffic, e.g. if your ISP uses private
# addresses (see RFC 1918) in their network. If in doubt, remove these rules.
# For details see:
#   * ftp://ftp.iana.org/assignments/ipv4-address-space
#   * http://www.cymru.com/Documents/bogon-bn-agg.txt
#------------------------------------------------------------------------------

$IPTABLES -A INPUT -s 0.0.0.0/7 -j DROP
$IPTABLES -A INPUT -s 2.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 5.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 7.0.0.0/8 -j DROP
#$IPTABLES -A INPUT -s 10.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 23.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 27.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 31.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 36.0.0.0/7 -j DROP
$IPTABLES -A INPUT -s 39.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 42.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 49.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 50.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 77.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 78.0.0.0/7 -j DROP
$IPTABLES -A INPUT -s 92.0.0.0/6 -j DROP
$IPTABLES -A INPUT -s 96.0.0.0/4 -j DROP
$IPTABLES -A INPUT -s 112.0.0.0/5 -j DROP
$IPTABLES -A INPUT -s 120.0.0.0/8 -j DROP
# $IPTABLES -A INPUT -s 127.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 169.254.0.0/16 -j DROP
$IPTABLES -A INPUT -s 172.16.0.0/12 -j DROP
$IPTABLES -A INPUT -s 173.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 174.0.0.0/7 -j DROP
$IPTABLES -A INPUT -s 176.0.0.0/5 -j DROP
$IPTABLES -A INPUT -s 184.0.0.0/6 -j DROP
$IPTABLES -A INPUT -s 192.0.2.0/24 -j DROP
# $IPTABLES -A INPUT -s 192.168.0.0/16 -j DROP
$IPTABLES -A INPUT -s 197.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 198.18.0.0/15 -j DROP
$IPTABLES -A INPUT -s 223.0.0.0/8 -j DROP
$IPTABLES -A INPUT -s 224.0.0.0/3 -j DROP


#------------------------------------------------------------------------------
# Selectively allow certain outbound connections, block the rest.
# TODO: This could be tightened a bit more (limit source/dest port ranges).
#------------------------------------------------------------------------------

# Allow outgoing DNS requests. Few things will work without this.
$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT

# Allow outgoing HTTP requests. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT

# Allow outgoing HTTPS requests.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Allow outgoing SMTPS requests. Do NOT allow unencrypted SMTP!
# $IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 465 -j ACCEPT

# Allow outgoing "submission" requests.
# Submission (RFC 2476) is used for sending email, and uses port 587.
# This can be encrypted or unencrypted, depending on the server (I think).
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 587 -j ACCEPT

# Allow outgoing POP3S requests. Do NOT allow unencrypted POP3!
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT

# Allow outgoing SSH requests.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT

# Allow outgoing FTP requests. Unencrypted, use with care.
# Note: This usually needs the ip_conntrack_ftp kernel module.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT

# Allow outgoing NNTP requests. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 119 -j ACCEPT

# Allow outgoing NTP requests. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 123 -j ACCEPT

# Allow outgoing IRC requests. Unencrypted, use with care.
# Note: This usually needs the ip_conntrack_irc kernel module.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 6667 -j ACCEPT

# Allow outgoing requests to various proxies. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 8080 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 8090 -j ACCEPT

# Allow outgoing DHCP requests. Unencrypted, use with care.
# TODO: This is completely untested, I have no idea whether it works!
# TODO: I think this can be tightened a bit more.
$IPTABLES -A OUTPUT -m state --state NEW -p udp \
          --sport 67:68 --dport 67:68 -j ACCEPT

# Allow outgoing CVS requests. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 2401 -j ACCEPT

# Allow outgoing SVN requests. Unencrypted, use with care.
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 3690 -j ACCEPT

# Allow outgoing Tor (http://tor.eff.org) requests.
# Note: Do _not_ use unencrypted protocols over Tor (sniffing is possible)!
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9001 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9002 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9030 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9031 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9090 -j ACCEPT
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9091 -j ACCEPT

# Allow outgoing Bacula (http://www.bacula.org) requests.
# Unencrypted (usually), use with care.
# Ports: Console -> DIR:9101, DIR -> SD:9103, DIR -> FD:9102, FD -> SD:9103
$IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9101 -j ACCEPT
# $IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9103 -j ACCEPT
# $IPTABLES -A OUTPUT -m state --state NEW -p tcp --dport 9102:9103 -j ACCEPT

# Allow outgoing OpenVPN requests.
$IPTABLES -A OUTPUT -m state --state NEW -p udp --dport 1194 -j ACCEPT

# TODO: ICQ, ...


#------------------------------------------------------------------------------
# Selectively allow certain inbound connections, block the rest.
# TODO: This could be tightened a bit more (limit source/dest port ranges).
#------------------------------------------------------------------------------

# Allow incoming DNS requests.
# $IPTABLES -A INPUT -m state --state NEW -p udp --dport 53 -j ACCEPT
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 53 -j ACCEPT

# Allow incoming HTTP requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 80 -j ACCEPT

# Allow incoming HTTPS requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 443 -j ACCEPT

# Allow incoming POP3 requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 110 -j ACCEPT

# Allow incoming POP3S requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 995 -j ACCEPT

# Allow incoming SMTP requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 25 -j ACCEPT

# Allow incoming SSH requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 22 -j ACCEPT

# Allow incoming FTP requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 21 -j ACCEPT

# Allow incoming NNTP requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 119 -j ACCEPT

# Allow incoming BitTorrent requests.
# TODO: Are these already handled by ACCEPTing established/related traffic?
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 6881 -j ACCEPT
# $IPTABLES -A INPUT -m state --state NEW -p udp --dport 6881 -j ACCEPT

# Allow incoming nc requests.
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 2030 -j ACCEPT
# $IPTABLES -A INPUT -m state --state NEW -p udp --dport 2030 -j ACCEPT

# Allow incoming Bacula (http://www.bacula.org) requests.
# Ports: Console -> DIR:9101, DIR -> SD:9103, DIR -> FD:9102, FD -> SD:9103
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 9102 -j ACCEPT
# $IPTABLES -A INPUT -m state --state NEW -p tcp --dport 9101:9103 -j ACCEPT


#------------------------------------------------------------------------------
# Explicitly log and reject everything else.
#------------------------------------------------------------------------------

# Use REJECT instead of REJECTLOG if you don't need/want logging.
$IPTABLES -A INPUT -j REJECTLOG
$IPTABLES -A OUTPUT -j REJECTLOG
$IPTABLES -A FORWARD -j REJECTLOG


#------------------------------------------------------------------------------
# Testing the firewall.
#------------------------------------------------------------------------------

# You should check/test that the firewall really works, using for example
# iptables -vnL, nmap, ping, telnet, ...


#------------------------------------------------------------------------------
# Exit gracefully.
#------------------------------------------------------------------------------

exit 0


