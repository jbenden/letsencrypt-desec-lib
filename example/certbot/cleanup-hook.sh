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

desec_acme_challenge_delete "$CERTBOT_DOMAIN"
