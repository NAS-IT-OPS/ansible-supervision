#!/bin/sh
## ANSIBLE_ROLE_BASE_SETUP
## environment : production
## module      : rhel_security_check
####
#
# 2021-06-06 - pbaudrier : creation
#
# vérification des security updates sur les redhat
# envoi d'un mail si updates needed
#
#####

yum=$(which yum)
updateinfo=$($yum --quiet updateinfo 2>/dev/null)
needsecupdate=$(echo $updateinfo|grep -i security)

[[ $needsecupdate != "" ]] && echo $updateinfo | mail -s "Security updates needed for $(hostname)" admins@icm-institute.org