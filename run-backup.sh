#!/bin/bash

# This script can be run as a cron or anacron job to create regular backups. It
# first creates a new backup and then prunes old backups to limit disk usage.
#
# A typical anacrontab line to perform daily backups with this script would
# look something like this:
#
#       1   5   remote-backup   /PATH_TO_THIS_SCRIPT/run-backup.sh

# Generate a backup.
/YOUR_PATH_HERE/backup.sh -c

# Prune archives.
/YOUR_PATH_HERE/backup.sh -p

