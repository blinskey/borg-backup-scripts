#!/bin/bash

# This script is sourced by the main Borg backup script. It exports the Borg
# repository passphrase for this machine. This file's ownership and permissions
# should be set to root:root and 600 to prevent exposure of the passphrase.
#
# This passphrase will be required when restoring a backup, so make sure to
# keep a copy of it in a safe location.
#
# Passphrases can be generated with the pwgen tool.
export BORG_PASSPHRASE=MySecretPassphrase
