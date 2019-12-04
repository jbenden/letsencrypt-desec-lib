#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2019 Daniel Schwierzeck
#

SCRIPT_ROOT=$(readlink -m "$(dirname "$0")/..")
# shellcheck source=src/lib-desec.bash
source "$SCRIPT_ROOT/src/lib-desec.bash"

present() {
    local -r domain_orig="$1"
    local -r token_value="$2"
    local domain

    # remove leading _acme-challenge. and trailing dot
    domain="${domain_orig#_acme-challenge.}"
    domain="${domain%.}"

    desec_acme_challenge_create "$domain" "$token_value" || \
        desec_acme_challenge_update "$domain" "$token_value" || \
            desec_die "failed to deploy challenge for domain $domain"

    desec_acme_challenge_poll "$domain" "$token_value" || \
        desec_die "challenge record for domain $domain not published on DNS server within timeout"
}

cleanup() {
    local -r domain_orig="$1"
    local -r token_value="$2"
    local domain

    # remove leading _acme-challenge. and trailing dot
    domain="${domain_orig#_acme-challenge.}"
    domain="${domain%.}"

    desec_acme_challenge_delete "$domain" || \
        desec_die "failed to delete challenge for domain $domain"
}

timeout() {
    echo '{"timeout": 120, "interval": 5}'
}

handler="${1:-unset}"
if [[ "$handler" =~ ^(present|cleanup|timeout)$ ]]; then
    # set DESECIO_DOMAIN and DESECIO_TOKEN and optionally DESECIO_TTL in
    # your environment
    desec_init_env

    # alternatively copy and adapt example/desecio.conf to your needs
    #desec_init_file "desec.conf"

    shift
    "$handler" "$@"
fi
