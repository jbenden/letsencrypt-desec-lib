#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2019 Daniel Schwierzeck
#

SCRIPT_ROOT=$(readlink -m "$(dirname "$0")/../..")
# shellcheck source=src/lib-desec.bash
source "$SCRIPT_ROOT/src/lib-desec.bash"

# set DESECIO_DOMAIN and DESECIO_TOKEN and optionally DESECIO_TTL in
# your environment
desec_init_env

# alternatively copy and adapt example/desecio.conf to your needs
#desec_init_file "desecio.conf"

# TODO: implement RFC7671 8.1 key rollover
# - add TLSA record for new certificate chain
# - wait 2 * TTL
# - deploy new certificate chain
# - remove old TLSA record

domain=${1:-unset}
test "$domain" != "unset" || desec_die "no domain given"

hash=$(desec_hash_cert "/etc/letsencrypt/live/$domain/fullchain.pem")
desec_tlsa_update "$domain" "443" "tcp" "3 0 1" "$hash" || \
    desec_tlsa_create "$domain" "443" "tcp" "3 0 1" "$hash"
