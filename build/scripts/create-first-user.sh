#!/bin/bash
# Oppretter standardbruker 'bazzite' med passord 'bazzite' ved første oppstart.
# Brukeren må bytte passord ved neste innlogging.
set -euo pipefail

USERNAME="bazzite"

if id "$USERNAME" &>/dev/null; then
    exit 0
fi

useradd -m -G wheel,video,render,input "$USERNAME"
echo "${USERNAME}:${USERNAME}" | chpasswd
chage -d 0 "$USERNAME"

systemctl disable stueos-firstboot-user.service
