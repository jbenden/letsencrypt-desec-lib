# letsencrypt-desec.io
Bash library and hook scripts for managing [Let's Encrypt](https://letsencrypt.org/) certificates with Dynamic DNS provider [deSEC](https://desec.io/#!/en/).

The Bash library is a small wrapper around the [deSEC DNS REST API](https://desec.readthedocs.io/en/latest/) and can be used to easily implement hook scripts for the DNS-01 challenge in Let's Encrypt ACME clients. Examples for [dehydrated](https://github.com/lukas2511/dehydrated/) and [certbot](https://certbot.eff.org/) are provided.


[![CircleCI](https://circleci.com/gh/danielschwierzeck/letsencrypt-desec.io/tree/master.svg?style=svg)](https://circleci.com/gh/danielschwierzeck/letsencrypt-desec.io/tree/master)
