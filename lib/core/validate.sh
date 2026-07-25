#!/usr/bin/env bash

# shellcheck disable=2034

# Common username and hostname conventions.
regex_valid_username="^[a-z_][a-z0-9_-]{0,31}$"
regex_valid_hostname="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"
regex_valid_directory="^[^/\0]+$"

# Match the string ($1) to the regular expression ($2)
re_match() { [[ "$1" =~ $2 ]]; }
