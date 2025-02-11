#!/bin/sh

#========================================================
# Adm agent install script
#
# @link     https://www.admin.im
# @github   https://github.com/AdmUU/Admin.IM
# @contact  dev@admin.im
# @license  https://github.com/AdmUU/Admin.IM/blob/main/LICENSE
#========================================================

INSTALL_DIR="/usr/local/share/admuu"
INSTALL_BIN_PATH="${INSTALL_DIR}/agent/adm-agent"
CONFIG_FILE="${INSTALL_DIR}/agent/config.yaml"
UPDATE_SERVER="${UPDATE_SERVER:-get.admin.im}"
API_SERVER=""
API_KEY=""
SECRET=""
SHARE="no"
SHARE_NAME=""
SPONSOR_ID=""
NEW_VERSION=""
GREEN='\033[32m'
RED='\033[0;31m'
BLUE='\033[0;36m'
RESET='\033[0m'
MAX_RETRIES=3
RETRY_DELAY=5

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -a URL           API server URL"
    echo "  -k KEY           API key"
    echo "  -s SECRET        Secret key"
    echo "  -share [yes|no]  Share this node (default: no)"
    echo "  -sharename NAME  Share name"
    echo "  -sid ID          Sponsor ID"
    echo "  -h               Display this help message"
}

success() {
    printf "${GREEN}OK[$(date '+%Y-%m-%d %H:%M:%S')] %s${RESET}\n" "$*"
}

error() {
    printf "${RED}ERR[$(date '+%Y-%m-%d %H:%M:%S')] %s${RESET}\n" "$*"
}

tip() {
    printf "${BLUE}INFO${RESET}[$(date '+%Y-%m-%d %H:%M:%S')] %s\n" "$*"
}

menu() {
    while true; do
        echo "请选择要执行的操作 / Please select an operation:"
        echo ""
        echo -e "${GREEN}1.${RESET} 安装 / Install"
        echo -e "${GREEN}2.${RESET} 卸载 / Uninstall"
        echo " --------------"
        echo -e "${GREEN}0.${RESET} 退出 / Exit"
        echo ""
        echo -n "请输入选项 / Please enter your choice [0-2]: "
        read choice

        case $choice in
            1)
                check_update
                install
                register
                break
                ;;
            2)
                uninstall "true"
                break
                ;;
            0)
                echo "退出 / Exiting..."
                exit 0
                ;;
            *)
                echo "无效的选项，请重新输入 / Invalid option, please try again."
                ;;
        esac
    done
}

check_root() {
   if [ "$(id -u)" -eq 0 ]; then
       return 0
   else
       if ! command -v sudo >/dev/null 2>&1; then
           error "This script requires root privileges. Please install sudo or run as root." >&2
           exit 1
       fi

       if ! sudo -n true 2>/dev/null; then
           error "This script requires sudo privileges. Please run with sudo or as root." >&2
           exit 1
       fi
   fi
}

uninstall() {
    local delete_files=${1:-false}

    if systemctl list-unit-files | grep -q "adm-agent.service"; then

        systemctl stop adm-agent.service 2>/dev/null || true

        systemctl disable adm-agent.service 2>/dev/null || true

        "$INSTALL_BIN_PATH" uninstall

        systemctl daemon-reload

        if ! systemctl list-unit-files | grep -q "adm-agent.service"; then
            if [ -z "$NEW_VERSION" ]; then
                success "Adm-agent service successfully uninstalled."
            else
                success "The old version has been uninstalled."
            fi
        else
            warning "Failed to uninstall adm-agent service."
        fi
    else
        [ "$NEW_VERSION" = "" ] && tip "Adm-agent service is not installed."
    fi

    if [ "$delete_files" = "true" ]; then
        if id admuu &>/dev/null; then
            userdel -r admuu 2>/dev/null
            success "User 'admuu' has been deleted."
        fi

        rm -rf "/etc/systemd/system/adm-agent.service.d"
        rm -rf "/usr/local/share/admuu"
        rm -rf "/usr/local/bin/adm-agent"
        success "Adm-agent files have been deleted."
    fi
}

check_root

if [ "$1" = "uninstall" ]; then
    uninstall "true"
    exit $?
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -a)
            [ -n "$2" ] && API_SERVER="$2" && shift
            ;;
        -k)
            [ -n "$2" ] && API_KEY="$2" && shift
            ;;
        -s)
            [ -n "$2" ] && SECRET="$2" && shift
            ;;
        -share)
            [ -n "$2" ] && SHARE="$2" && shift
            ;;
        -sharename)
            [ -n "$2" ] && SHARE_NAME="$2" && shift
            ;;
        -sid)
            [ -n "$2" ] && SPONSOR_ID="$2" && shift
            ;;
        -h)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

get_arch() {
    local uarch
    uarch=$(uname -m)
    case "$uarch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        armv7l|armv6l)
            arch="arm"
            ;;
        mips64)
            arch="mips64"
            ;;
        mips)
            arch="mips"
            ;;
        i386|i686)
            arch="386"
            ;;
        *)
            error "Unsupported os architecture"
            return 1
            ;;
    esac
    return 0
}

compare_version_part() {
    local ver1=$1
    local ver2=$2

    [ -z "$ver1" ] && ver1=0
    [ -z "$ver2" ] && ver2=0

    if [ "$ver1" -gt "$ver2" ]; then
        return 1
    elif [ "$ver1" -lt "$ver2" ]; then
        return 2
    fi
    return 0
}

compare_versions() {
    local ver1 ver2 result major1 major2 minor1 minor2 patch1 patch2

    ver1=$(echo "$1" | sed 's/^v//')
    ver2=$(echo "$2" | sed 's/^v//')

    major1=$(echo "$ver1" | cut -d. -f1)
    major2=$(echo "$ver2" | cut -d. -f1)

    compare_version_part "$major1" "$major2"
    result=$?
    [ $result -ne 0 ] && return $result

    minor1=$(echo "$ver1" | cut -d. -f2)
    minor2=$(echo "$ver2" | cut -d. -f2)

    compare_version_part "$minor1" "$minor2"
    result=$?
    [ $result -ne 0 ] && return $result

    patch1=$(echo "$ver1" | cut -d. -f3)
    patch2=$(echo "$ver2" | cut -d. -f3)

    compare_version_part "$patch1" "$patch2"
    return $?
}

curl_with_retry() {
    local retries=0
    local max_retries=$MAX_RETRIES
    local delay=$RETRY_DELAY
    local response

    while [ $retries -lt $max_retries ]; do
        response=$(curl "$@")
        if [ $? -eq 0 ]; then
            echo "$response"
            return 0
        fi
        retries=$((retries + 1))
        if [ $retries -lt $max_retries ]; then
            tip "Connection failed, retrying in ${delay} seconds... (Attempt $retries of $max_retries)"
            sleep $delay
        fi
    done

    return 1
}

check_update() {
    local result
    local version_check
    local install_version="0.0.0"

    if [ -f "$INSTALL_BIN_PATH" ]; then
        install_version=$($INSTALL_BIN_PATH -v)
    fi

    if [ -n "$install_version" ] && [ "$install_version" != "0.0.0" ]; then
        version_check="?v=$install_version"
    fi

    local metadata
    metadata=$(curl_with_retry -s --max-time 10 "https://${UPDATE_SERVER}/admuu/adm-agent/latest/metadata.json${version_check}")
    if [ -z "$metadata" ]; then
        error "Failed to get release metadata" >&2
        exit 1
    fi

    version=$(echo "$metadata" | awk -F'"version":"' '{print $2}' | awk -F'"' '{print $1}')
    if [ -z "$version" ]; then
        error "Failed to parse version from metadata" >&2
        exit 1
    fi

    download_url="https://${UPDATE_SERVER}/admuu/adm-agent/${version}/adm-agent_linux_${arch}.tar.gz${version_check}"

    tip "Latest version: $version"

    compare_versions "${install_version%%-*}" "${version%%-*}"
    result=$?
    NEW_VERSION=false
    case $result in
        0)
            tip "The latest version has been installed"
            ;;
        1)
            echo "The current version ($install_version) is higher than the latest version ($version)"
            ;;
        2)
            NEW_VERSION=true
            ;;
    esac
}

install() {
    local tmp_file

    if [ ! -f "$INSTALL_BIN_PATH" ] && (([ -z "$API_SERVER" ] || [ -z "$API_KEY" ] || [ -z "$SECRET" ]) && [ "$SHARE" != "yes" ]); then
        error "Please provide API server address, key, secret or set share to yes."
        exit 1
    fi

    if [ "$NEW_VERSION" != "true" ]; then
        return
    fi

    create_user admuu

    if [ ! -d "${INSTALL_DIR}/agent" ]; then
        if ! mkdir -p "${INSTALL_DIR}/agent" 2>/dev/null; then
            error "Error: Failed to create install directory ${INSTALL_DIR}/agent"
            exit 1
        fi
    fi

    tmp_file="/tmp/adm-agent_${version}_${arch}.tar.gz"

    tip "Downloading..."
    if ! curl_with_retry -s -L -o "$tmp_file" "$download_url"; then
        error "Download $download_url failed." >&2
        rm -f "$tmp_file"
        exit 1
    fi

    checksums=$(curl_with_retry -s "https://${UPDATE_SERVER}/admuu/adm-agent/${version}/checksums.txt")
    if [ -z "$checksums" ]; then
        error "Failed to fetch checksums" >&2
        rm -f "$tmp_file"
        exit 1
    fi

    expected_checksum=$(echo "$checksums" | grep "adm-agent_linux_${arch}.tar.gz" | awk '{print $1}')
    if [ -z "$expected_checksum" ]; then
        error "Checksum not found for this architecture" >&2
        rm -f "$tmp_file"
        exit 1
    fi

    actual_checksum=$(sha256sum "$tmp_file" | awk '{print $1}')

    if [ "$actual_checksum" != "$expected_checksum" ]; then
        error "Checksum verification failed" >&2
        rm -f "$tmp_file"
        exit 1
    fi

    tip "Checksum verified successfully"

    archive_dir="/tmp/adm-agent_${version}/"
    mkdir -p "$archive_dir"
    tar -xzf "$tmp_file" -C "$archive_dir"

    if ! mv "${archive_dir}/adm-agent" "$INSTALL_BIN_PATH"; then
        error "Failed to install to $INSTALL_BIN_PATH" >&2
        rm -f "$tmp_file"
        rm -rf "$archive_dir"
        exit 1
    fi

    if [ ! -f "/usr/local/bin/adm-agent" ]; then
        ln -s /usr/local/share/admuu/agent/adm-agent /usr/local/bin/adm-agent
    fi

    chmod +x "$INSTALL_BIN_PATH"
    rm -f "$tmp_file"
    rm -rf "$archive_dir"

    "$INSTALL_BIN_PATH" --version

}

create_user() {
    local username="$1"
    local description="Adm Service User"

    if id "$username" &>/dev/null; then
        return 0
    fi

    useradd -r -m -s /sbin/nologin \
        -d "${INSTALL_DIR}" \
        -c "$description" \
        --no-log-init \
        "$username"

    if [ $? -ne 0 ]; then
        error "Error: Failed to create user $username"
        exit 1
    fi

    rm -f "${INSTALL_DIR}"/.bashrc "${INSTALL_DIR}"/.bash_logout "${INSTALL_DIR}"/.profile
}

register() {
    local regrsp

    if ( [ -n "$API_SERVER" ] && [ -n "$API_KEY" ] && [ -n "$SECRET" ] ) || [ "$SHARE" = "yes" ]; then
        tip "Registering agent..."

        regrsp=$("$INSTALL_BIN_PATH" register \
            -a "$API_SERVER" \
            -k "$API_KEY" \
            -s "$SECRET" \
            --share "$SHARE" \
            --sharename "$SHARE_NAME" \
            --sponsorid "$SPONSOR_ID" 2>&1)

        local reg_status=$?

        if [ $reg_status -ne 0 ]; then
            error "Failed to register node."
            error "$regrsp"
            return 1
        fi

        uninstall

        "$INSTALL_BIN_PATH" install

        # chown -R admuu:admuu "$CONFIG_FILE"
        chown -R admuu:admuu "${INSTALL_DIR}/agent"

        sed -i '/^RestartSec/cRestartSec=10' /etc/systemd/system/adm-agent.service

        local service_d="/etc/systemd/system/adm-agent.service.d"
        if [ ! -d "${service_d}" ]; then
            mkdir "${service_d}"
        fi
        if [ ! -f "${service_d}/capabilities.conf" ]; then
            cat > "${service_d}/capabilities.conf" <<EOF
[Service]
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW
EOF
        fi
    fi

    systemctl daemon-reload

    "$INSTALL_BIN_PATH" restart

    systemctl status adm-agent

    success "$(printf "Successfully installed adm-agent %s" "$version")"
}

get_arch

menu