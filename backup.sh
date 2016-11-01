#!/bin/bash
#
###############################################################################
#
# Copyright (c) 2016 Benjamin Linskey
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
###############################################################################
#
# THIS SCRIPT HAS NOT BEEN FULLY TESTED. USE AT YOUR OWN RISK.
#
# This is a simple wrapper script for the BorgBackup program. It is primarily
# intended for use in cron or anacron jobs but also provides some functions
# that can simplify interactive maintenance of a Borg repository.
#
# The commands in this script assume a compressed, encrypted, remote
# repository, but the script can be modified for other use cases with minimal
# changes.  Set up public key SSH authentication in order to allow
# non-interactive access to your server.  The script exports BORG_PASSPHRASE so
# that encrypted repositories can be modified by cron jobs. Accordingly, this
# file's ownership and permissions should be restricted to prevent exposure of
# the password. You should keep a separate, secure copy of all files and
# passphrases necessary to access your data; see the Borg documentation for
# details.
#
# The "remote-path=borg1" option is intended for use of Borg 1.x with rsync.net
# and should be removed or modified as necessary for your situation.
#
# Borg output is set at the default level ("warning") and is output to
# stdout and stderr. In addition, the script logs basic information to the
# system log.
#
# Borg resources:
#
# - Source code: https://github.com/borgbackup/borg
# - Documentation: https://borgbackup.readthedocs.io/en/stable/

set -o errexit
set -o nounset
set -o pipefail

# Repository passphrase, required for all encrypted repositories.
# The permissions of this file should be restricted to prevent accidental
# exposure of this passphrase.
export BORG_PASSPHRASE=MySecretPassphrase

# These variables define the path to the Borg repository on the backup machine.
# They can be modified to support local backups if necessary.
#
# Note that the current configuration assumes a one-client-per-repository
# setup, which avoids inefficiencies that can occur when backing up multiple
# machines to a single repository. For details, see
# https://borgbackup.readthedocs.io/en/stable/faq.html#can-i-backup-from-multiple-servers-into-a-single-repository
readonly USER=username
readonly HOST=example.com
readonly REPO="$(hostname)" # Path to repository on the host
readonly TARGET="${USER}@${HOST}:${REPO}"

# Valid options are "none", "keyfile", and "repokey". See Borg docs.
readonly ENCRYPTION_METHOD=keyfile

# Compression algorithm and level. See Borg docs.
readonly COMPRESSION_ALGO=zlib
readonly COMPRESSION_LEVEL=6

# List of paths to back up.
readonly SOURCE_PATHS="${HOME}/Documents
                       ${HOME}/Music
                       ${HOME}/Videos
                       ${HOME}/Pictures
                       ${HOME}/Public
                       ${HOME}/src
                       ${HOME}/bin
                       ${HOME}/.mail"

# Number of days, weeks, &c. of backups to keep when pruning.
readonly KEEP_DAILY=7
readonly KEEP_WEEKLY=4
readonly KEEP_MONTHLY=6
readonly KEEP_YEARLY=1

# $1...: command line arguments
main() {
    if [[ "$#" != 1 ]]; then
        usage
        exit 1
    fi

    parse_args "$@"
    exit 0
}

# $1...: command line arguments
parse_args() {
    while getopts ":ichpdq" opt; do
        case $opt in
            i)  init
                exit 0
                ;;
            c)  create
                exit 0
                ;;
            h)  usage
                exit 0
                ;;
            p)  prune
                exit 0
                ;;
            d)  delete
                exit 0
                ;;
            q)  quota
                exit 0
                ;;
            v)  check
                exit 0
                ;;
            :)  printf "Missing argument for option %s\n" "$OPTARG" >&2
                usage
                exit 1
                ;;
            *)  printf "Invalid option: %s\n" "$opt" >&2
                usage
                exit 1
                ;;
        esac
    done
}

usage() {
    printf "Usage: %s OPTION\n" "$(basename "$0")"
    printf "  %s\t%s\n" "-c" "create a new backup"
    printf "  %s\t%s\n" "-d" "delete repository"
    printf "  %s\t%s\n" "-h" "print this help text and exit"
    printf "  %s\t%s\n" "-i" "initialize a new repository"
    printf "  %s\t%s\n" "-p" "prune backups"
    printf "  %s\t%s\n" "-q" "check remote storage quota usage"
    printf "  %s\t%s\n" "-v" "verify repository consistency"
}

init() {
    logger -p user.info "Starting Borg repository initialization: ${TARGET}"

    borg init --remote-path=borg1 --encryption="${ENCRYPTION_METHOD}" "${TARGET}"

    logger -p user.info "Finished Borg repository initialization ${TARGET}"
}

create() {
    logger -p user.info "Starting Borg archive creation: ${TARGET}"

    # shellcheck disable=SC2086
    # We want $SOURCE_PATHS to undergo word splitting here.
    borg create --remote-path=borg1 \
        --compression "${COMPRESSION_ALGO},${COMPRESSION_LEVEL}" \
        "${TARGET}::{now:%Y%m%d}" $SOURCE_PATHS

    logger -p user.info "Finished Borg archive creation: ${TARGET}"
}

prune() {
    logger -p user.info "Starting Borg prune: ${TARGET}"

    borg prune --remote-path=borg1 \
        --keep-daily="${KEEP_DAILY}" --keep-weekly="${KEEP_WEEKLY}" \
        --keep-monthly="${KEEP_MONTHLY}" --keep-yearly="${KEEP_YEARLY}"

    logger -p user.info "Finished Borg prune: ${TARGET}"
}

delete() {
    printf "Are you sure you want to permanently delete the repository '%s'? [y/N]" "$TARGET"
    read -r response
    if [[ ${response:0:1} != "Y" && ${response:0:1} != "y" ]]; then
        printf "Aborted"
        exit 1
    fi

    # shellcheck disable=SC2029
    # We want the repository name to expand on the client side.
    ssh "${TARGET}" rm -rf "${REPO}"

    logger -p user.info "Deleted Borg repository: ${TARGET}"
}

quota() {
    # Putting quotes around "quota" prevents spurious Shellcheck warnings.
    ssh "${TARGET}" "quota"
}

check() {
    borg check --remote-path=borg1 "${TARGET}"
}

on_failure() {
    logger -p user.warning "Borg backup terminated unexpectedly"
}

trap on_failure SIGHUP SIGINT SIGTERM

main "$@"
