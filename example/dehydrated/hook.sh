#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2019 Daniel Schwierzeck
#

SCRIPT_ROOT=$(readlink -m "$(dirname "$0")/../..")
# shellcheck source=src/lib-desec.bash
source "$SCRIPT_ROOT/src/lib-desec.bash"

deploy_challenge() {
    local -r domain="$1"
    # shellcheck disable=SC2034
    local -r token_file="$2"
    local -r token_value="$3"

    desec_acme_challenge_create "$domain" "$token_value" || \
        desec_acme_challenge_update "$domain" "$token_value" || \
            desec_err "failed to deploy challenge for domain $domain"

    desec_acme_challenge_poll "$domain" "$token_value" || \
        desec_err "challenge record for domain $domain not published on DNS server within timeout"
}

clean_challenge() {
    local -r domain="$1"

    desec_acme_challenge_delete "$domain" || \
        desec_err "failed to delete challenge for domain $domain"
}

deploy_cert() {
    local -r domain="$1"
    # shellcheck disable=SC2034
    local -r keyfile="$2"
    # shellcheck disable=SC2034
    local -r certfile="$3"
    local -r fullchainfile="$4"
    # shellcheck disable=SC2034
    local -r chainfile="$5"
    # shellcheck disable=SC2034
    local -r timestamp="$6"
    local hash

    # TODO: implement RFC7671 8.1 key rollover
    # - add TLSA record for new certificate chain
    # - wait 2 * TTL
    # - deploy new certificate chain
    # - remove old TLSA record

    hash=$(desec_hash_cert "$fullchainfile")
    desec_tlsa_update "$domain" "443" "tcp" "3 0 1" "$hash" || \
        desec_tlsa_create "$domain" "443" "tcp" "3 0 1" "$hash" || \
            desec_err "failed to update TLSA record for domain $domain"
}

handler="${1:-unset}"
if [[ "$handler" =~ ^(deploy_challenge|clean_challenge|deploy_cert)$ ]]; then
    # set DESECIO_DOMAIN and DESECIO_TOKEN and optionally DESECIO_TTL in
    # your environment
    desec_init_env

    # alternatively copy and adapt example/desecio.conf to your needs
    #desec_init_file "desecio.conf"

    shift
    "$handler" "$@"
fi
