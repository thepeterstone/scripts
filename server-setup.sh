#!/bin/bash

####
# server-setup.sh - configure a new server
#
# This script automatically configures a fresh Debian install.
#
# Features:
#   - apply updates, install apps
#   - add user & allow ssh (with keys)
#   - security: apply a firewall and app-specific rules
#
####

# Use SSL here - scripts will be downloaded from this domain and run as ROOT!
MASTER='https://static.terst.org/files/'
# What's your name, baby?
USER=thepeterstone
# Disable interactive mode for unattended setup
INTERACTIVE=false
# Server to ping once host setup is complete
HEARTBEAT="http://terst.org/api/heartbeat"


main() {
    upgrade_and_install && setup_security && add_user

    # ping heartbeat server
    IPS=$(ifconfig|awk -F: '/inet addr/ {print $2}'|awk '{print $1}'|xargs|sed 's/ /+/g')
    curl -Ifs "$HEARTBEAT?host=$(hostname)&ip=$IPS&comment=$0" >/dev/null 2>&1
}


add_user() {
    echo "Adding user ($USER)..."
    # add our user, but don't enable login
    useradd --shell /bin/zsh $USER
    # find the homedir
    HOME="/home/$USER"
    # add an authorized_key for SSH access - user must have root password to admin the box!
    mkdir -p $HOME/.ssh
    echo "  installing ssh key (from $MASTER)"
    curl "$MASTER/$USER.pub" >$HOME/.ssh/authorized_keys
    chown -R $USER.$USER $HOME/.ssh
}

setup_security() {
    echo "Setting up security..."
    # Firewall
    curl "$MASTER/fw_base.sh" >fw_base.sh
    # If running interactively, customize the firewall first.
    # The default firewall settings allow incoming SSH (tcp/22) and selected outgoing traffic.
    if [[ "$INTERACTIVE" == "true" ]]; then
        vim fw_base.sh
    fi
    echo "  enabling the firewall"
    chmod +x fw_base.sh && ./fw_base.sh

    # App-specific: SSH
    echo "  configuring ssh"
    #sed -i 's/PermitRootLogin Yes/PermitRootLogin No/' /etc/ssh/sshd_config
    sed -i 's/Port 22/Port 7383/' /etc/ssh/sshd_config
    service ssh restart

    # root password
    if [[ "$INTERACTIVE" == "true" ]]; then
        passwd
    fi
}

upgrade_and_install() {
    echo "Updating software"
    apt-get update && apt-get -y upgrade && apt-get -y dist-upgrade
    echo "  installing tools"
    apt-get -yq install encfs tmux vim-nox zsh
}

main
