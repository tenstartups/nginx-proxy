FROM nginx:alpine

# Set environment variables.
ENV \
  HTTP_LISTEN_PORT=80

# Install packages.
RUN apk add --update bash bind-tools gettext libcap nodejs npm openssl python3 py3-pip

# Install Python modules
RUN \
  pip3 install --upgrade pip && \
  pip3 install awscli --upgrade

# Install NodeJS modules
RUN \
  npm install -g envhandlebars

# Backup the existing nginx configuration.
RUN bash -c "mv /etc/nginx /etc/nginx.save"

# Copy files into place.
COPY etc/nginx /etc/nginx/
COPY var/www/default /var/www/default/
COPY entrypoint.sh /docker-entrypoint
COPY healthcheck.js ./

ARG APP_UID=1001
ARG APP_GID=1001
RUN addgroup -g "${APP_GID}" -S app \
  && adduser -u "${APP_UID}" -S -G app -h /var/cache/nginx -D app \
  && mkdir -p /tmp/nginx \
  && chown -R app:app /etc/nginx /var/www /docker-entrypoint /var/cache/nginx /tmp/nginx . \
  && chmod +x /docker-entrypoint \
  && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

# Define the healthcheck
HEALTHCHECK --interval=12s --timeout=12s --start-period=30s CMD node ./healthcheck.js

# Define the entrypoint.
ENTRYPOINT ["/docker-entrypoint"]

# Define the default command.
CMD ["nginx", "-g", "daemon off;"]

USER app:app
