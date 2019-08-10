#!/usr/bin/env bash
#
# SPDX-License-Identifier: MIT
#
# Copyright (c) 2019 Daniel Schwierzeck
#

declare -g desec_domain=''
declare -g desec_token=''
declare -gr desec_rest_api='https://desec.io/api/v1'
declare -gr desec_ns1='ns1.desec.io'
declare -gi desec_ttl=60
declare -gi desec_http_code=0

desec_info() {
    # shellcheck disable=SC2210
    echo "INFO: $*"
}

desec_err() {
    # shellcheck disable=SC2210
    echo "ERROR: $*" >&2
}

desec_die() {
    desec_err "$*"
    exit 1
}

desec_init_env() {
    desec_domain=${DESECIO_DOMAIN:=unset}
    test "$desec_domain" != "unset" || desec_die "DESECIO_DOMAIN is not set"

    desec_token=${DESECIO_TOKEN:=unset}
    test "$desec_token" != "unset" || desec_die "DESECIO_TOKEN is not set"

    desec_ttl=${DESECIO_TTL:=60}
}

desec_json_data() {
    local -r var_name=$1

    IFS=$'\n' read -r -d '' "$var_name" || true
}

desec_init_file() {
    local -r cfg_file=$1

    test -f "$cfg_file" || desec_die "Config file $cfg_file not found"

    # shellcheck disable=SC1090
    source "$cfg_file"
    desec_init_env
}

desec_auth_email_update() {
    local -r email=$1
    local data

    desec_json_data data <<EOF
{
    "email" : "$email"
}
EOF

    desec_http_code=$(curl -sL -X PUT "$desec_rest_api/auth/me/" \
        -w "%{http_code}" -o /dev/null \
        --header 'Accept: application/json' \
        --header "Authorization: Token $desec_token" \
        --header 'Content-Type: application/json' \
        --data "$data")

    test "$desec_http_code" -eq 200
}

desec_rrset_create() {
    local -r domain=$1
    local -r record=$2
    local -r type=$3
    local subname data

    subname="${domain%%.${desec_domain}}"

    desec_json_data data <<EOF
{
    "records" : [ $record ],
    "subname" : "$subname",
    "ttl" : $desec_ttl,
    "type" : "$type"
}
EOF

    desec_http_code=$(curl -sL -X POST "$desec_rest_api/domains/$desec_domain/rrsets/" \
        -w "%{http_code}" -o /dev/null \
        --header 'Accept: application/json' \
        --header "Authorization: Token $desec_token" \
        --header 'Content-Type: application/json' \
        --data "$data")

    test "$desec_http_code" -eq 201
}

desec_rrset_update() {
    local -r domain=$1
    local -r record=$2
    local -r type=$3
    local subname data

    subname="${domain%%.${desec_domain}}"

    desec_json_data data <<EOF
{
    "records" : [ $record ],
    "ttl" : $desec_ttl,
    "type" : "$type"
}
EOF

    desec_http_code=$(curl -sL -X PUT "$desec_rest_api/domains/$desec_domain/rrsets/${subname}.../$type/" \
        -w "%{http_code}" -o /dev/null \
        --header 'Accept: application/json' \
        --header "Authorization: Token $desec_token" \
        --header 'Content-Type: application/json' \
        --data "$data")

    test "$desec_http_code" -eq 200
}

desec_rrset_delete() {
    local -r domain=$1
    local -r type=$2
    local subname

    subname="${domain%%.${desec_domain}}"

    desec_http_code=$(curl -sL -X DELETE "$desec_rest_api/domains/$desec_domain/rrsets/${subname}.../$type/" \
        -w "%{http_code}" -o /dev/null \
        --header 'Accept: application/json' \
        --header "Authorization: Token $desec_token" \
        --header 'Content-Type: application/json')

    test "$desec_http_code" -eq 204
}

desec_acme_challenge_create() {
    local -r domain="_acme-challenge.${1}"
    local -r challenge=$2

    desec_rrset_create "$domain" "\"\\\"$challenge\\\"\"" "TXT"
}

desec_acme_challenge_update() {
    local -r domain="_acme-challenge.${1}"
    local -r challenge=$2

    desec_rrset_update "$domain" "\"\\\"$challenge\\\"\"" "TXT"
}

desec_acme_challenge_delete() {
    local -r domain="_acme-challenge.${1}"

    desec_rrset_delete "$domain" "TXT"
}

desec_tlsa_create() {
    local -r domain=$1
    local -r port=$2
    local -r proto=$3
    local -r type=$4
    local -r tlsa_domain="_${port}._${proto}.${domain}"
    local -r hash_current=$5
    local -r hash_pending=${6:-unset}
    local record

    record="\"$type $hash_current\""
    if [ "$hash_pending" != "unset" ]; then
        record+=", \"$type $hash_pending\""
    fi

    desec_rrset_create "$tlsa_domain" "$record" "TLSA"
}

desec_tlsa_update() {
    local -r domain=$1
    local -r port=$2
    local -r proto=$3
    local -r type=$4
    local -r tlsa_domain="_${port}._${proto}.${domain}"
    local -r hash_current=$5
    local -r hash_pending=${6:-unset}
    local record

    record="\"$type $hash_current\""
    if [ "$hash_pending" != "unset" ]; then
        record+=", \"$type $hash_pending\""
    fi

    desec_rrset_update "$tlsa_domain" "$record" "TLSA"
}

desec_tlsa_delete() {
    local -r domain=$1
    local -r port=$2
    local -r proto=$3
    local -r tlsa_domain="_${port}._${proto}.${domain}"

    desec_rrset_delete "$tlsa_domain" "TLSA"
}

desec_cname_create() {
    local -r domain="${1}.${desec_domain}"
    local -r record=$2

    desec_rrset_create "$domain" "\"$record\"" "CNAME"
}

desec_cname_update() {
    local -r domain="${1}.${desec_domain}"
    local -r record=$2

    desec_rrset_update "$domain" "\"$record\"" "CNAME"
}

desec_cname_delete() {
    local -r domain="${1}.${desec_domain}"

    desec_rrset_delete "$domain" "CNAME"
}

desec_acme_challenge_poll() {
    local -r domain="_acme-challenge.${1}"
    local -r challenge=$2
    local -i waited=0
    local -ir delay=2
    local -ir timeout=120

    while [ $waited -lt $timeout ]; do
        if host -t TXT "$domain" "$desec_ns1" | grep -q "\"$challenge\"" ; then
            return 0
        fi
        sleep $delay
        waited=$((waited += delay))
    done

    return 1
}

desec_hash_cert() {
    local -r fullchain="$1"

    openssl x509 -in "$fullchain" -outform DER | openssl sha256 | cut -d' ' -f2
}
