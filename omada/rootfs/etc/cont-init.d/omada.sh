#!/usr/bin/with-contenv bashio

set -e

declare certfile
declare keyfile

# set environment variables
export TZ
TZ="${TZ:-Etc/UTC}"
MANAGE_HTTP_PORT="${MANAGE_HTTP_PORT:-8088}"
MANAGE_HTTPS_PORT="${MANAGE_HTTPS_PORT:-8043}"
PORTAL_HTTP_PORT="${PORTAL_HTTP_PORT:-8088}"
PORTAL_HTTPS_PORT="${PORTAL_HTTPS_PORT:-8843}"
SHOW_SERVER_LOGS="${SHOW_SERVER_LOGS:-true}"
SHOW_MONGODB_LOGS="${SHOW_MONGODB_LOGS:-false}"
TLS_1_11_ENABLED="${TLS_1_11_ENABLED:-false}"


for DIR in data work logs
do
  # Ensures the data of the UniFi Network Application is store outside the container
  if ! bashio::fs.directory_exists "/data/omada/${DIR}"; then
      mkdir -p "/data/omada/${DIR}"
  fi
  rm -fr "/opt/tplink/EAPController/${DIR}"
  ln -s "/data/omada/${DIR}" "/opt/tplink/EAPController/${DIR}"
done

keyfile="/ssl/$(bashio::config 'keyfile')"
certfile="/ssl/$(bashio::config 'certfile')"
if bashio::fs.file_exists "${certfile}" \
  && bashio::fs.file_exists "${keyfile}";
then
  bashio::log.info "Certificates found: SSL is available"
else
  bashio::log.error "SSL is not enabled"
  bashio::exit.nok
fi

# set default time zone and notify user of time zone
bashio::log.info "Time zone set to '${TZ}'"

set_port_property() {
  # check to see if we are trying to bind to privileged port
  if [ "${3}" -lt "1024" ] && [ "$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)" = "1024" ]
  then
    bashio::log.error "Unable to set '${1}' to ${3}; 'ip_unprivileged_port_start' has not been set.  See https://github.com/mbentley/docker-omada-controller#unprivileged-ports"
    exit 1
  fi

  bashio::log.info "Setting '${1}' to ${3} in omada.properties"
  sed -i "s/^${1}=${2}$/${1}=${3}/g" /opt/tplink/EAPController/properties/omada.properties
}

# replace MANAGE_HTTP_PORT if not the default
if [ "${MANAGE_HTTP_PORT}" != "8088" ]
then
  set_port_property manage.http.port 8088 "${MANAGE_HTTP_PORT}"
fi

# replace MANAGE_HTTPS_PORT if not the default
if [ "${MANAGE_HTTPS_PORT}" != "8043" ]
then
  set_port_property manage.https.port 8043 "${MANAGE_HTTPS_PORT}"
fi

# replace PORTAL_HTTP_PORT if not the default
if [ "${PORTAL_HTTP_PORT}" != "8088" ]
then
  set_port_property portal.http.port 8088 "${PORTAL_HTTP_PORT}"
fi

# replace PORTAL_HTTPS_PORT if not the default
if [ "${PORTAL_HTTPS_PORT}" != "8843" ]
then
  set_port_property portal.https.port 8843 "${PORTAL_HTTPS_PORT}"
fi

# make sure permissions are set appropriately on each directory
for DIR in data work logs
do
  OWNER="$(stat -c '%u' /opt/tplink/EAPController/${DIR})"
  GROUP="$(stat -c '%g' /opt/tplink/EAPController/${DIR})"

  if [ "${OWNER}" != "omada" ] || [ "${GROUP}" != "omada" ]
  then
    # notify user that uid:gid are not correct and fix them
    bashio::log.warning "owner or group (${OWNER}:${GROUP}) not set correctly on '/opt/tplink/EAPController/${DIR}'"
    bashio::log.info "setting correct permissions"
    chown -R omada:omada "/opt/tplink/EAPController/${DIR}"
  fi
done

# validate permissions on /tmp
TMP_PERMISSIONS="$(stat -c '%a' /tmp)"
if [ "${TMP_PERMISSIONS}" != "1777" ]
then
  bashio::log.warning "permissions are not set correctly on '/tmp' (${TMP_PERMISSIONS})!"
  bashio::log.info "setting correct permissions (1777)"
  chmod -v 1777 /tmp
fi

# check to see if there is a db directory; create it if it is missing
if [ ! -d "/opt/tplink/EAPController/data/db" ]
then
  bashio::log.info "Database directory missing; creating '/opt/tplink/EAPController/data/db'"
  mkdir /opt/tplink/EAPController/data/db
  chown omada:omada /opt/tplink/EAPController/data/db
fi

# Import a cert from a possibly mounted secret or file at /cert
if [ -f "${keyfile}" ] && [ -f "${certfile}" ]
then
  # see where the keystore directory is; check for old location first
  if [ -d /opt/tplink/EAPController/keystore ]
  then
    # keystore in the parent folder before 5.3.1
    KEYSTORE_DIR="/opt/tplink/EAPController/keystore"
  else
    # keystore directory moved to the data directory in 5.3.1
    KEYSTORE_DIR="/opt/tplink/EAPController/data/keystore"

    # check to see if the KEYSTORE_DIR exists (it won't on upgrade)
    if [ ! -d "${KEYSTORE_DIR}" ]
    then
      bashio::log.info "creating keystore directory (${KEYSTORE_DIR})"
      mkdir "${KEYSTORE_DIR}"
      bashio::log.info "setting permissions on ${KEYSTORE_DIR}"
      chown omada:omada "${KEYSTORE_DIR}"
    fi
  fi

  bashio::log.info "Importing cert from ${keyfile} & ${certfile}"
  # delete the existing keystore
  rm -f "${KEYSTORE_DIR}/eap.keystore"

  # example certbot usage: ./certbot-auto certonly --standalone --preferred-challenges http -d mydomain.net
  openssl pkcs12 -export \
    -inkey "${keyfile}" \
    -in "${certfile}" \
    -certfile "${certfile}" \
    -name eap \
    -out "${KEYSTORE_DIR}/eap.keystore" \
    -passout pass:tplink

  # set ownership/permission on keystore
  chown omada:omada "${KEYSTORE_DIR}/eap.keystore"
  chmod 400 "${KEYSTORE_DIR}/eap.keystore"
fi

# re-enable disabled TLS versions 1.0 & 1.1
if [ "${TLS_1_11_ENABLED}" = "true" ]
then
  bashio::log.info "Re-enabling TLS 1.0 & 1.1"
  sed -i 's#^jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1,#jdk.tls.disabledAlgorithms=SSLv3,#' /etc/java-8-openjdk/security/java.security
fi

# tail the omada logs if set to true
if [ "$(bashio::config 'serverLogs')" = "true" ]
then
  tail -F -n 0 /opt/tplink/EAPController/logs/server.log &
fi

# tail the mongodb logs if set to true
if [ "$(bashio::config 'mongoLogs')" = "true" ]
then
  tail -F -n 0 /opt/tplink/EAPController/logs/mongod.log &
fi

# run the actual command as the omada user
# exec gosu omada "${@}"
