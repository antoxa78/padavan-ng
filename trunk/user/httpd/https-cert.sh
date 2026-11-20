#!/bin/sh

if [ ! -x /usr/bin/openssl ] && [ ! -x /opt/bin/openssl ]; then
  echo "Unable to find the 'openssl' executable!" >&2
  echo "Please install 'openssl-util' package from Entware." >&2
  exit 1
fi

umask 0022

DH_GEN=0
DH_BITS=1024
RSA_BITS=1024
CA_DAYS=3653
CERT_DAYS=365
DSTDIR=/etc/storage/https
SSL_EXT_FILE=/etc/ssl/openssl_ext2.cnf
ECPARAM=ecparam.pem

func_help() {
  local BOLD="echo -ne \\033[1m"
  local NORM="echo -ne \\033[0m"
  echo "Create self-signed certificate for HTTP SSL server." >&2
  echo >&2
  echo "`$BOLD`Usage:`$NORM`" >&2
  echo "    $0 -n `$BOLD`common_name`$NORM` [ -b `$BOLD`rsa_bits/ec_name`$NORM` ] [ -d `$BOLD`days_valid`$NORM` ] [ -p {DH} ]" >&2
  echo >&2
  echo "`$BOLD`Example:`$NORM`" >&2
  echo "    $0 -n myname.no-ip.com -b 2048 -d 30" >&2
  echo >&2
  echo "`$BOLD`Defaults:`$NORM`"
  echo "    rsa_bits=`$BOLD`$RSA_BITS`$NORM`, days_valid=`$BOLD`$CERT_DAYS`$NORM`" >&2
  echo >&2
  exit 1
}

echo_done() {
  echo -e " *\033[60G [ done ]"
}

echo_process() {
  echo -ne " + $@\r"
}

is_cn_valid() {
  # RFC 1034 (https://tools.ietf.org/html/rfc1034#section-3.5)
  if [ -n "`echo $1 | sed 's/^[a-zA-Z][0-9a-zA-z\.-]\{1,253\}[0-9a-zA-Z]$//'`" ] ; then
    return 1
  fi
  for i in  `echo $1 | sed 's/\./ /g'` ; do
    if [ `echo -n $i | wc -c` -gt 63 ] ; then
      return 1
    fi
  done
  return 0
}

is_ipv4() {
  case "$1" in
    ''|*[!0-9.]*) return 1 ;;
  esac
  echo "$1" | awk -F. '
    NF == 4 {
      for (i = 1; i <= 4; i++)
        if ($i !~ /^[0-9]+$/ || $i > 255) exit 1
      exit 0
    }
    { exit 1 }
  '
}

add_ip_san() {
  local ip="$1"
  is_ipv4 "$ip" || return 0
  case ",$IP_SANS," in
    *",IP:$ip,"*) ;;
    *) IP_SANS="${IP_SANS:+$IP_SANS,}IP:$ip" ;;
  esac
}

get_lan_ipv4() {
  local ip n
  # AP mode stores the live address in lan_ipaddr_t; router mode uses
  # lan_ipaddr.  Fall back to the br0 address if NVRAM is not populated.
  for n in lan_ipaddr_t lan_ipaddr; do
    ip=$(nvram get "$n" 2>/dev/null)
    is_ipv4 "$ip" && { echo "$ip"; return 0; }
  done
  ip=$(ip -4 addr show br0 2>/dev/null | awk '/inet / {sub(/\/.*/,"",$2); print $2; exit}')
  is_ipv4 "$ip" && { echo "$ip"; return 0; }
  return 1
}

create_cert() {
  [ -z "$CN" ] && func_help
  if ! is_ipv4 "$CN" && ! is_cn_valid $CN ; then
     echo >&2
     echo "Warning: $CN is not a valid host name." >&2
     echo >&2
  fi

  [ -d $DSTDIR ] || mkdir -m 755 -p $DSTDIR
  if ! cd $DSTDIR ; then
    echo "Error: can't cd to $DSTDIR" >&2
    return 1
  fi

  # Check if -sha256 is supported
  local DGST_ALG
  DGST_ALG="-sha1"
  openssl list -1 --digest-commands 2>&1 | grep -q 'sha256' && DGST_ALG="-sha256"

  rm -f $SSL_EXT_FILE
  # DNS name plus the router's LAN IPv4 address, so both
  # https://my.router and https://<lan-ip> validate without a warning.
  local SAN="DNS:${CN}"
  [ "$CN" != "my.router" ] && SAN="$SAN,DNS:my.router"
  IP_SANS=""
  add_ip_san "$CN"
  add_ip_san "$(get_lan_ipv4)"
  [ -n "$IP_SANS" ] && SAN="$SAN,$IP_SANS"

  cat > $SSL_EXT_FILE << EOF
[ server ]
basicConstraints=CA:FALSE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer:always
extendedKeyUsage=serverAuth,clientAuth
keyUsage=critical,digitalSignature,keyEncipherment
subjectAltName=${SAN}
EOF

  local C_PARAM="rsa:${RSA_BITS}"
  if echo $RSA_BITS | grep -q '^[bpsw]'; then
    openssl ecparam -name "$RSA_BITS" -out "$ECPARAM"
    C_PARAM="ec:$ECPARAM"
  fi

  echo_process "Creating CA"
  openssl req -nodes -x509 -days $CA_DAYS -newkey $C_PARAM \
            -outform PEM -out ca.crt -keyout ca.key \
            $DGST_ALG -subj "/CN=HTTPS CA" &>/dev/null
  chmod 600 ca.key
  echo_done

  echo_process "Creating certificate request"
  openssl req -nodes -days $CERT_DAYS -newkey $C_PARAM \
            -outform PEM -out server.csr -keyout server.key \
            $DGST_ALG -subj "/CN=$CN" &>/dev/null
  chmod 600 server.key
  echo_done

  echo_process "Signing request"
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
               -clrext -out server.crt $DGST_ALG -extfile $SSL_EXT_FILE \
               -days $CERT_DAYS -extensions server &>/dev/null
  rm -f server.csr
  echo_done

  if [ $DH_GEN -eq 1 ] ; then
    echo_process "Creating DH Parameters (may take long time, be patient)"
    openssl dhparam -out dh1024.pem $DH_BITS &>/dev/null
    echo_done
  fi

  [[ -f "$ECPARAM" ]] && rm -f "$DSTDIR/$ECPARAM"
  rm -f ca.srl
}

while [ $# -gt 0 ] ; do
  case "$1" in
    -n) CN="$2" ; shift 2 ;;
    -b) RSA_BITS=$2 ; shift 2 ;;
    -d) CERT_DAYS=$2 ; shift 2 ;;
    -p) DH_GEN=1 ; shift 1 ;;
     *) func_help ; ;;
  esac
done

create_cert

exit $?
