#!/bin/bash
# ==================================================
# Скрипт автоматической установки Xray (VLESS + WS + TLS / VLESS + XHTTP)
# Ориентирован на: Ubuntu 20.04+, Debian 10+, CentOS 7+
# Особенности: Самоподписанный сертификат, порт 443 для WS+TLS, 2053 для XHTTP, SNI google.com.
# Включает автоматическое включение TCP BBR для оптимизации скорости.
# ==================================================

# Режим установки: ws, xhttp или both
INSTALL_MODE="ws" # по умолчанию WS+TLS

# Конфигурационные переменные
VLESS_PORT_WS=443
VLESS_PORT_XHTTP=2053
WS_PATH="/$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)"
LOG_DIR="/var/log/xray"
CONFIG_DIR="/usr/local/etc/xray"
CERT_DIR="/usr/local/etc/xray/certs"
CERT_FILE="${CERT_DIR}/server.crt"
KEY_FILE="${CERT_DIR}/server.key"

# Вспомогательные функции
Color_Off='\033[0m'
BGreen='\033[1;32m'
BYellow='\033[1;33m'
BRed='\033[1;31m'
BCyan='\033[1;36m'

log_info() { echo -e "${BCyan}[INFO] $1${Color_Off}"; }
log_warn() { echo -e "${BYellow}[WARN] $1${Color_Off}"; }
log_error() { echo -e "${BRed}[ERROR] $1${Color_Off}"; exit 1; }

# Проверка прав суперпользователя
if [[ "$EUID" -ne 0 ]]; then
  log_error "Этот скрипт необходимо запускать с правами root (sudo)."
fi

# Выбор режима установки
echo -e "${BCyan}Выберите режим установки:${Color_Off}"
echo "  1 - VLESS + WS + TLS (порт 443, SNI google.com)"
echo "  2 - VLESS + XHTTP (порт 2053, SNI google.com)"
echo "  3 - ОБА РЕЖИМА (порты 443 и 2053, общий UUID)"
read -rp "Введите номер [1/2/3]: " MODE_CHOICE

case "$MODE_CHOICE" in
  2)
    INSTALL_MODE="xhttp"
    log_info "Выбран режим: VLESS + XHTTP (порт ${VLESS_PORT_XHTTP}, SNI google.com)"
    ;;
  3)
    INSTALL_MODE="both"
    log_info "Выбран режим: VLESS + WS + XHTTP (порты ${VLESS_PORT_WS} и ${VLESS_PORT_XHTTP}, SNI google.com)"
    ;;
  *)
    INSTALL_MODE="ws"
    log_info "Выбран режим: VLESS + WS + TLS (порт ${VLESS_PORT_WS}, SNI google.com)"
    ;;
esac

# Определение пути для QR-кода
USER_HOME=""
if [[ -n "$SUDO_USER" ]]; then
    if command -v getent &> /dev/null; then
        USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        log_warn "Команда 'getent' не найдена."
    fi
fi

if [[ -z "$USER_HOME" ]]; then
    USER_HOME="/root"
    log_warn "Не удалось определить домашний каталог пользователя sudo. QR-коды будут в ${USER_HOME}"
fi

QR_CODE_FILE_WS="${USER_HOME}/vless_ws_qr.png"
QR_CODE_FILE_XHTTP="${USER_HOME}/vless_xhttp_qr.png"
mkdir -p "$(dirname "$QR_CODE_FILE_WS")"

if [[ -n "$SUDO_USER" && -n "$USER_HOME" && "$USER_HOME" != "/root" ]]; then
    NEED_CHOWN_QR=true
else
    NEED_CHOWN_QR=false
fi

log_info "Запуск скрипта установки VLESS VPN на базе Xray..."
log_info "Режим: ${INSTALL_MODE}"

set -eu

# Определение ОС и установка зависимостей
log_info "Определение операционной системы и установка зависимостей..."

if [[ ! -f /etc/os-release ]]; then
    log_error "Файл /etc/os-release не найден. Не удалось определить ОС."
fi

. /etc/os-release

if [[ -z "${ID:-}" ]]; then
    log_error "Не удалось определить ID ОС в /etc/os-release."
fi

OS="$ID"

if [[ -z "${VERSION_ID:-}" ]]; then
    log_warn "VERSION_ID не определен. Возможно, rolling release."
    if [[ -n "${VERSION_CODENAME:-}" ]]; then
        VERSION_ID="${VERSION_CODENAME}"
        log_info "Используется VERSION_CODENAME: ${VERSION_ID}"
    else
        VERSION_ID="unknown"
        log_warn "VERSION_ID установлен в 'unknown'."
    fi
fi

log_info "Обнаружена ОС: $OS ${VERSION_ID}"

log_info "Обновление списка пакетов и установка зависимостей..."

case $OS in
    ubuntu|debian|linuxmint|pop|neon)
        log_info "Обнаружен Debian/Ubuntu. Установка пакетов..."
        apt update -y || log_error "Не удалось обновить список пакетов."
        apt install -y curl wget unzip socat qrencode jq coreutils openssl bash-completion || log_error "Не удалось установить зависимости."
        ;;
    centos|almalinux|rocky|rhel|fedora)
        log_info "Обнаружен RHEL/CentOS. Установка пакетов..."
        if [[ "$OS" == "centos" ]]; then
            MAJOR_VERSION=$(echo "$VERSION_ID" | cut -d. -f1)
            if [[ "$MAJOR_VERSION" == "7" ]]; then
                log_info "Установка EPEL для CentOS 7..."
                yum install -y epel-release || log_warn "Не удалось установить epel-release."
            fi
        fi
        if command -v dnf &> /dev/null; then
            dnf update -y || log_warn "Не удалось обновить через dnf."
            dnf install -y curl wget unzip socat qrencode jq coreutils openssl bash-completion policycoreutils-python-utils util-linux || log_error "Не удалось установить зависимости."
        else
            yum update -y || log_warn "Не удалось обновить через yum."
            if [[ "$OS" == "centos" ]] && [[ "${MAJOR_VERSION:-}" == "7" ]]; then
                yum install -y curl wget unzip socat qrencode jq coreutils openssl bash-completion policycoreutils-python util-linux || log_error "Не удалось установить зависимости."
            else
                yum install -y curl wget unzip socat qrencode jq coreutils openssl bash-completion policycoreutils-python-utils util-linux || log_error "Не удалось установить зависимости."
            fi
        fi
        ;;
    *)
        log_error "ОС $OS не поддерживается. Поддержка: Ubuntu, Debian, CentOS, AlmaLinux, Rocky."
        ;;
esac

log_info "Зависимости установлены."

# Включение TCP BBR
log_info "Включение TCP BBR для оптимизации скорости..."

BBR_CONF="/etc/sysctl.d/99-bbr.conf"

if ! grep -q "net.core.default_qdisc=fq" "$BBR_CONF" 2>/dev/null ; then
    echo "net.core.default_qdisc=fq" | tee "$BBR_CONF" > /dev/null
fi

if ! grep -q "net.ipv4.tcp_congestion_control=bbr" "$BBR_CONF" 2>/dev/null ; then
    echo "net.ipv4.tcp_congestion_control=bbr" | tee -a "$BBR_CONF" > /dev/null
fi

if sysctl -p "$BBR_CONF"; then
    log_info "TCP BBR успешно применен."
else
    log_warn "BBR не поддерживается ядром (требуется 4.9+)."
fi

# Установка Xray
log_info "Установка Xray..."

if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
    log_error "Ошибка при установке Xray."
fi

if ! command -v xray &> /dev/null; then
    log_error "'xray' не найден после установки."
fi

log_info "Xray установлен: $(xray version | head -n 1)"

# Генерация UUID
USER_UUID=$(xray uuid)
if [[ -z "$USER_UUID" ]]; then
    log_error "Не удалось сгенерировать UUID."
fi

log_info "UUID: ${USER_UUID}"

# Настройка Firewall
log_info "Настройка брандмауэра..."

if [[ "$INSTALL_MODE" == "both" ]]; then
  PORTS_TO_OPEN="${VLESS_PORT_WS} ${VLESS_PORT_XHTTP}"
else
  if [[ "$INSTALL_MODE" == "ws" ]]; then
    PORTS_TO_OPEN="${VLESS_PORT_WS}"
  else
    PORTS_TO_OPEN="${VLESS_PORT_XHTTP}"
  fi
fi

if command -v ufw &> /dev/null; then
    for PORT in $PORTS_TO_OPEN; do
      log_info "UFW: открытие порта ${PORT}/tcp..."
      ufw allow ${PORT}/tcp || log_warn "ufw allow ошибка."
    done
    if ufw status | grep -qw active; then
        ufw reload || log_error "Не удалось перезагрузить UFW."
    else
        log_warn "UFW неактивен. Активируйте: sudo ufw enable"
    fi
elif command -v firewall-cmd &> /dev/null; then
    for PORT in $PORTS_TO_OPEN; do
      log_info "firewalld: открытие ${PORT}/tcp..."
      firewall-cmd --permanent --add-port=${PORT}/tcp || log_warn "firewall-cmd ошибка."
    done
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --reload || log_error "Не удалось перезагрузить firewalld."
    else
         log_warn "firewalld неактивен."
    fi
    if [[ -f /usr/sbin/sestatus ]] && sestatus | grep "SELinux status:" | grep -q "enabled"; then
        log_info "SELinux включен. Настройка..."
        if command -v semanage &> /dev/null; then
            for PORT in $PORTS_TO_OPEN; do
              semanage port -a -t http_port_t -p tcp ${PORT} 2>/dev/null || semanage port -m -t http_port_t -p tcp ${PORT} || log_warn "SELinux порт ${PORT} ошибка."
            done
            setsebool -P httpd_can_network_connect 1 || log_warn "SELinux httpd_can_network_connect ошибка."
            log_info "SELinux настроен."
        else
            log_warn "'semanage' не найден."
        fi
    fi
else
    log_warn "UFW/firewalld не найдены. Откройте порты вручную: $PORTS_TO_OPEN"
fi

# Генерация сертификата TLS
log_info "Генерация TLS сертификата..."

SERVER_IP=$(curl -s4 https://ipinfo.io/ip || curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.me)

if [[ -z "$SERVER_IP" ]]; then
    log_error "Не удалось определить IPv4."
fi

log_info "IP сервера: $SERVER_IP"

mkdir -p "$CERT_DIR"

if ! openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -days 3650 \
    -subj "/CN=${SERVER_IP}" \
    -addext "subjectAltName = IP:${SERVER_IP}"; then
    log_error "Ошибка генерации TLS сертификата."
fi

if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
    log_error "Файлы TLS не найдены."
fi

log_info "TLS сертификат сгенерирован для IP: $SERVER_IP"

chmod 644 "$CERT_FILE"
chgrp nobody "$KEY_FILE" 2>/dev/null || chgrp nogroup "$KEY_FILE" 2>/dev/null || log_warn "Не удалось chgrp ключ."
chmod 640 "$KEY_FILE"

log_info "Права на сертификаты установлены."

# Создание конфигурации Xray
log_info "Создание ${CONFIG_DIR}/config.json..."

mkdir -p "$LOG_DIR"
chown nobody:nobody "$LOG_DIR" 2>/dev/null || chown nobody:nogroup "$LOG_DIR" 2>/dev/null || log_warn "Не удалось chown LOG_DIR."
mkdir -p "$CONFIG_DIR"

if [[ "$INSTALL_MODE" == "ws" ]]; then
  cat > "${CONFIG_DIR}/config.json" << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_DIR}/access.log",
    "error": "${LOG_DIR}/error.log"
  },
  "dns": {
    "servers": [
      "https://1.1.1.1/dns-query",
      "https://8.8.8.8/dns-query",
      "https://9.9.9.9/dns-query",
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ],
    "queryStrategy": "UseIP"
  },
  "inbounds": [
    {
      "port": ${VLESS_PORT_WS},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "minVersion": "1.3",
          "serverName": "google.com",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {
            "Host": "google.com"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "fakedns"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "port": 53,
        "network": "udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
elif [[ "$INSTALL_MODE" == "xhttp" ]]; then
  cat > "${CONFIG_DIR}/config.json" << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_DIR}/access.log",
    "error": "${LOG_DIR}/error.log"
  },
  "dns": {
    "servers": [
      "https://1.1.1.1/dns-query",
      "https://8.8.8.8/dns-query",
      "https://9.9.9.9/dns-query",
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ],
    "queryStrategy": "UseIP"
  },
  "inbounds": [
    {
      "port": ${VLESS_PORT_XHTTP},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "serverName": "google.com",
          "minVersion": "1.2",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "xhttpSettings": {
          "mode": "stream-one"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "fakedns"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "port": 53,
        "network": "udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
else
  # Режим both: оба inbound
  cat > "${CONFIG_DIR}/config.json" << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "${LOG_DIR}/access.log",
    "error": "${LOG_DIR}/error.log"
  },
  "dns": {
    "servers": [
      "https://1.1.1.1/dns-query",
      "https://8.8.8.8/dns-query",
      "https://9.9.9.9/dns-query",
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ],
    "queryStrategy": "UseIP"
  },
  "inbounds": [
    {
      "port": ${VLESS_PORT_WS},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "minVersion": "1.3",
          "serverName": "google.com",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "wsSettings": {
          "path": "${WS_PATH}",
          "headers": {
            "Host": "google.com"
          }
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "fakedns"]
      }
    },
    {
      "port": ${VLESS_PORT_XHTTP},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${USER_UUID}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["h2", "http/1.1"],
          "serverName": "google.com",
          "minVersion": "1.2",
          "certificates": [
            {
              "certificateFile": "${CERT_FILE}",
              "keyFile": "${KEY_FILE}"
            }
          ]
        },
        "xhttpSettings": {
          "mode": "stream-one"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "fakedns"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "port": 53,
        "network": "udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
fi

log_info "Конфиг Xray создан."

# Проверка конфигурации Xray
log_info "Проверка конфигурации Xray..."

if ! /usr/local/bin/xray -test -config "${CONFIG_DIR}/config.json"; then
    log_error "Конфиг Xray содержит ошибки."
fi

log_info "Конфиг Xray корректен."

# Настройка и запуск службы Xray
log_info "Настройка и перезапуск службы Xray..."

systemctl enable xray || log_warn "Не удалось enable xray."
systemctl restart xray || log_error "Не удалось restart xray."

log_info "Ожидание запуска (3 сек)..."
sleep 3

if ! systemctl is-active --quiet xray; then
    log_error "Служба Xray не запустилась. Логи: journalctl -u xray -n 50 или ${LOG_DIR}/error.log"
fi

log_info "Служба Xray запущена."

# Генерация VLESS ссылок и QR-кодов
log_info "Генерация VLESS ссылок и QR-кодов..."

if ! command -v jq &> /dev/null; then
    log_error "'jq' не найден."
fi

WS_PATH_ENCODED=$(printf %s "$WS_PATH" | jq -sRr @uri)

if [[ -z "$WS_PATH_ENCODED" ]]; then
    log_error "URL-кодирование пути WS не удалось."
fi

VLESS_LINK_WS="vless://${USER_UUID}@${SERVER_IP}:${VLESS_PORT_WS}?type=ws&path=${WS_PATH_ENCODED}&security=tls&sni=google.com&allowInsecure=1#VLESS-WS-TLS-google.com"
VLESS_LINK_XHTTP="vless://${USER_UUID}@${SERVER_IP}:${VLESS_PORT_XHTTP}?type=xhttp&security=tls&sni=google.com&alpn=h2&allowInsecure=1#VLESS-XHTTP-google.com"

QR_WS_GENERATED=false
QR_XHTTP_GENERATED=false

if command -v qrencode &> /dev/null; then
    if [[ "$INSTALL_MODE" == "ws" || "$INSTALL_MODE" == "both" ]]; then
      if qrencode -o "$QR_CODE_FILE_WS" "$VLESS_LINK_WS"; then
          log_info "QR-код WS: ${QR_CODE_FILE_WS}"
          QR_WS_GENERATED=true
          if [[ "$NEED_CHOWN_QR" = true ]]; then
            if command -v id &> /dev/null; then
                SUDO_USER_GROUP=$(id -gn "$SUDO_USER" 2>/dev/null)
                if [[ -n "$SUDO_USER_GROUP" ]]; then
                     chown "$SUDO_USER":"$SUDO_USER_GROUP" "$QR_CODE_FILE_WS" || log_warn "chown QR_WS ошибка."
                fi
            fi
          fi
      else
          log_warn "QR-код WS не сгенерирован."
      fi
    fi

    if [[ "$INSTALL_MODE" == "xhttp" || "$INSTALL_MODE" == "both" ]]; then
      if qrencode -o "$QR_CODE_FILE_XHTTP" "$VLESS_LINK_XHTTP"; then
          log_info "QR-код XHTTP: ${QR_CODE_FILE_XHTTP}"
          QR_XHTTP_GENERATED=true
          if [[ "$NEED_CHOWN_QR" = true ]]; then
            if command -v id &> /dev/null; then
                SUDO_USER_GROUP=$(id -gn "$SUDO_USER" 2>/dev/null)
                if [[ -n "$SUDO_USER_GROUP" ]]; then
                     chown "$SUDO_USER":"$SUDO_USER_GROUP" "$QR_CODE_FILE_XHTTP" || log_warn "chown QR_XHTTP ошибка."
                fi
            fi
          fi
      else
          log_warn "QR-код XHTTP не сгенерирован."
      fi
    fi
else
    log_warn "'qrencode' не найден. QR-коды не сгенерированы."
fi

# Вывод итоговой информации
log_info "=================================================="
log_info "${BGreen} Установка VLESS VPN завершена! ${Color_Off}"
log_info "=================================================="

echo -e "${BYellow}IP-адрес сервера:${Color_Off} ${SERVER_IP}"
echo -e "${BYellow}UUID (общий):${Color_Off} ${USER_UUID}"
echo -e "${BYellow}SNI/Host:${Color_Off} google.com"
echo -e "${BYellow}Шифрование:${Color_Off} TLS (самоподписанный)"
echo -e "${BYellow}TCP BBR:${Color_Off} включен"
echo ""

if [[ "$INSTALL_MODE" == "ws" ]]; then
  echo -e "${BGreen}=== VLESS + WS + TLS ===${Color_Off}"
  echo -e "${BYellow}Порт:${Color_Off} ${VLESS_PORT_WS}"
  echo -e "${BYellow}Путь WS:${Color_Off} ${WS_PATH}"
  echo ""
  echo -e "${BGreen}Ссылка:${Color_Off}"
  echo -e "${VLESS_LINK_WS}"
  echo ""
  if [[ "$QR_WS_GENERATED" = true ]]; then
      echo -e "${BGreen}QR-код:${Color_Off} ${QR_CODE_FILE_WS}"
      echo -e "${BYellow}Команда:${Color_Off} qrencode -t ansiutf8 \"${VLESS_LINK_WS}\""
      echo ""
  fi
elif [[ "$INSTALL_MODE" == "xhttp" ]]; then
  echo -e "${BGreen}=== VLESS + XHTTP ===${Color_Off}"
  echo -e "${BYellow}Порт:${Color_Off} ${VLESS_PORT_XHTTP}"
  echo ""
  echo -e "${BGreen}Ссылка:${Color_Off}"
  echo -e "${VLESS_LINK_XHTTP}"
  echo ""
  if [[ "$QR_XHTTP_GENERATED" = true ]]; then
      echo -e "${BGreen}QR-код:${Color_Off} ${QR_CODE_FILE_XHTTP}"
      echo -e "${BYellow}Команда:${Color_Off} qrencode -t ansiutf8 \"${VLESS_LINK_XHTTP}\""
      echo ""
  fi
else
  echo -e "${BGreen}=== VLESS + WS + TLS (Port ${VLESS_PORT_WS}) ===${Color_Off}"
  echo -e "${BYellow}Путь WS:${Color_Off} ${WS_PATH}"
  echo ""
  echo -e "${BGreen}Ссылка WS:${Color_Off}"
  echo -e "${VLESS_LINK_WS}"
  echo ""
  if [[ "$QR_WS_GENERATED" = true ]]; then
      echo -e "${BGreen}QR-код WS:${Color_Off} ${QR_CODE_FILE_WS}"
      echo -e "${BYellow}Команда:${Color_Off} qrencode -t ansiutf8 \"${VLESS_LINK_WS}\""
      echo ""
  fi

  echo -e "${BGreen}=== VLESS + XHTTP (Port ${VLESS_PORT_XHTTP}) ===${Color_Off}"
  echo ""
  echo -e "${BGreen}Ссылка XHTTP:${Color_Off}"
  echo -e "${VLESS_LINK_XHTTP}"
  echo ""
  if [[ "$QR_XHTTP_GENERATED" = true ]]; then
      echo -e "${BGreen}QR-код XHTTP:${Color_Off} ${QR_CODE_FILE_XHTTP}"
      echo -e "${BYellow}Команда:${Color_Off} qrencode -t ansiutf8 \"${VLESS_LINK_XHTTP}\""
      echo ""
  fi
fi

echo -e "${BYellow}ВАЖНО - Настройка клиента:${Color_Off}"
echo -e "  1. Импортируйте ссылку или QR-код."
echo -e "  2. ${BRed}ОБЯЗАТЕЛЬНО${Color_Off} включите '${BRed}Разрешить небезопасное${Color_Off}'"
echo -e "     (Allow Insecure / skip cert verify / tlsAllowInsecure=1)."
echo -e "  3. Убедитесь, SNI/Host = ${BRed}google.com${Color_Off}"
echo -e "  4. Адрес сервера = IP вашего VPS (или домен)."
echo ""

echo -e "${BCyan}--- Управление службой Xray ---${Color_Off}"
echo -e "Статус:    ${BYellow}systemctl status xray${Color_Off}"
echo -e "Перезапуск: ${BYellow}systemctl restart xray${Color_Off}"
echo -e "Остановить:  ${BYellow}systemctl stop xray${Color_Off}"
echo -e "Автозапуск: ${BYellow}systemctl enable xray${Color_Off}"
echo ""

echo -e "${BCyan}--- Логи Xray ---${Color_Off}"
echo -e "Ошибки:  ${BYellow}tail -f ${LOG_DIR}/error.log${Color_Off}"
echo -e "Доступ:   ${BYellow}tail -f ${LOG_DIR}/access.log${Color_Off}"
echo -e "systemd:  ${BYellow}journalctl -u xray --output cat -f${Color_Off}"
echo ""

log_info "Установка завершена. Приятного использования!"

set +eu
exit 0
