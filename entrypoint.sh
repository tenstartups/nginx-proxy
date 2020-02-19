#!/bin/bash
set -e

NGINX_CONFIG_SOURCE_ENV_REGEX="^\s*NGINX_CONFIG_SOURCE(_([_A-Z0-9]+))?=(.+)\s*$"
BASIC_AUTH_ENV_REGEX="^\s*BASIC_AUTH(_([_A-Z0-9]+))?=([-_a-zA-Z0-9]+)[:](.+)\s*$"

# Create resolvers configuration
echo resolver $(awk 'BEGIN{ORS=" "} $1=="nameserver" {print $2}' "/etc/resolv.conf") ";" > "/etc/nginx/resolvers.conf"

# Copy configuration files into place
while read -r config_source ; do
  echo "Copying configurations from ${config_source}..."
  if [[ "${config_source}" = s3://* ]]; then
    # Download configuration files from AWS S3
    aws s3 cp "${config_source}/" "/etc/nginx/conf.d/" --recursive --include "*.conf" --include "*.conf.tmpl"
  else
    # Copy configuration files from mounted volume
    cp -v "${config_source}/"*.{conf,conf.tmpl} "/etc/nginx/conf.d/" 2>/dev/null || :
  fi
done < <(env | grep -E "${NGINX_CONFIG_SOURCE_ENV_REGEX}" | sed -r "s/${NGINX_CONFIG_SOURCE_ENV_REGEX}/\3/")

# Substitute environment variables into template files
find "/etc/nginx/conf.d/" -type f -name "*.conf.tmpl" | while read template_file; do
  tmp_conf_file=$(mktemp /tmp/nginx-conf.XXXXXXXXX)
  config_file="${template_file%.*}"
  envsubst < "${template_file}" > "${tmp_conf_file}"
  rm "${template_file}"
  cp "${tmp_conf_file}" "${config_file}"
  rm -r "${tmp_conf_file}"
done

while read -r basic_auth ; do
  username=$(echo "${basic_auth}" | cut -d ":" -f 1)
  password=$(echo "${basic_auth}" | cut -d ":" -f 2-)
  password_hash=$(openssl passwd -quiet -1 "${password}")
  echo "Adding HTTP Basic Auth user ${username}..."
  echo "${username}:${password_hash}"  >> "/etc/nginx/www-users.htpasswd"
done < <(env | grep -E "${BASIC_AUTH_ENV_REGEX}" | sed -r "s/${BASIC_AUTH_ENV_REGEX}/\3:\4/")

exec "$@"
