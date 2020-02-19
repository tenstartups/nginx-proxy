#!/bin/bash
set -e

NGINX_CONFIG_SOURCE_ENV_REGEX="^\s*NGINX_CONFIG_SOURCE(_([_A-Z0-9]+))?=(.+)\s*$"
BASIC_AUTH_ENV_REGEX="^\s*BASIC_AUTH(_([_A-Z0-9]+))?=([-_a-zA-Z0-9]+):(.+)\s*$"

# Create resolvers configuration
echo resolver $(awk 'BEGIN{ORS=" "} $1=="nameserver" {print $2}' "/etc/resolv.conf") ";" > "/etc/nginx/resolvers.conf"

# Copy configuration files into place
while read -r config_source ; do
  echo "Copying configurations from ${config_source}..."
  if [[ "${config_source}" = s3://* ]]; then
    # Download configuration files from AWS S3
    aws s3 cp "${config_source}/" "/etc/nginx/conf.d/" --recursive --include "*.conf"
  else
    # Copy configuration files from mounted volume
    cp -v "${config_source}/"*.conf "/etc/nginx/conf.d/"
  fi
done < <(env | grep -E "${NGINX_CONFIG_SOURCE_ENV_REGEX}" | sed -r "s/${NGINX_CONFIG_SOURCE_ENV_REGEX}/\3/")

while read -r basic_auth ; do
  username=$(echo "${basic_auth}" | cut -d ":" -f 1)
  password=$(echo "${basic_auth}" | cut -d ":" -f 2-)
  password_hash=$(openssl passwd -quiet -1 "${password}")
  echo "Adding HTTP Basic Auth user ${username}..."
  echo "${username}:${password_hash}"  >> "/etc/nginx/www-users.htpasswd"
done < <(env | grep -E "${BASIC_AUTH_ENV_REGEX}" | sed -r "s/${BASIC_AUTH_ENV_REGEX}/\3\4/")

exec "$@"
