#!/bin/bash
# script name: pocket-repo.sh
# version: 1.0.0
# supported os:
#     redos 7.3.6
#     redos 8.0
#     rocky 9.6
#     centos 7
#     astra 1.7.5
#     ubuntu 24.04
#     alt 10.4


# === Settings
AUTH_USER="nexus_user"
AUTH_PASS="nexus_password"
OUTPUT_BASE_DIR="/opt/localrepo"


# /// TECH VARS & FUNCTIONS ///

# === COLOR VARS
CLEAR_COLOR="\033[0m"
RED_COLOR="\033[31m"
GREEN_COLOR="\033[32m"

fail_ok() {
    if [ $? -eq 0 ]; then
        echo -e "[$GREEN_COLOR OK $CLEAR_COLOR] $1"
    else
        echo -e "[$RED_COLOR FAIL $CLEAR_COLOR] $1"
        exit 1
    fi
}

fail_ok_reverse() {
    if [ $? -eq 0 ]; then
        echo -e "[$RED_COLOR FAIL $CLEAR_COLOR] $1"
    else
        echo -e "[$GREEN_COLOR OK $CLEAR_COLOR] $1"
    fi
}

if which dnf >/dev/null 2>&1; then
    PM="dnf"
elif which yum >/dev/null 2>&1; then
    PM="yum"
elif which apt >/dev/null 2>&1; then
    PM="apt"
elif which apt-get >/dev/null 2>&1; then
    PM="apt-get"
else
    fail_ok "Packet manager not found"
fi

TARGET_REPO="$2"
PACKAGES_DIR="$OUTPUT_BASE_DIR/packages/$TARGET_REPO"
ARCHIVES_DIR="$OUTPUT_BASE_DIR/archives"
REPO_BASE="https://repo.data.rt.ru/repository/$TARGET_REPO"

download_file() {
    local url="$1"
    local dest="$2"
    if [ -f "$dest" ]; then
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    curl -u "$AUTH_USER:$AUTH_PASS" --retry 3 --retry-delay 2 -s -S -L -o "$dest" "$url"
}

detect_deb_dist() {
    for dist in 1.9_x86-64 1.8_x86-64 1.7_x86-64 focal; do
        if curl --user "$AUTH_USER:$AUTH_PASS" --silent --fail --output /dev/null "$REPO_BASE/dists/$dist/Release"; then
            fail_ok "Dists is defined"
            DIST_PATH="dists/$dist"
            return
        fi
    done
    fail_ok_reverse "Dists is defined"
    return 1
}

detect_repo_type() {
    if curl --user "$AUTH_USER:$AUTH_PASS" --silent --fail --output /dev/null "$REPO_BASE/repodata/repomd.xml"; then
        REPO_TYPE="rpm"
        fail_ok "Repository type detected: $REPO_TYPE"
    else
        if detect_deb_dist; then
            REPO_TYPE="deb"
            fail_ok "Repository type detected: $REPO_TYPE"
        else
            fail_ok "Repository type detection failed"
        fi
    fi
}

create_deb_repo() {
    mkdir -p "$PACKAGES_DIR/$DIST_PATH"
    fail_ok "Base structure created: $DIST_PATH"

    download_file "$REPO_BASE/$DIST_PATH/Release" "$PACKAGES_DIR/$DIST_PATH/Release" || exit 1

    PACKAGES_PATHS=$(grep -E 'main/binary-[a-zA-Z0-9]+.*Packages\.gz' "$PACKAGES_DIR/$DIST_PATH/Release" | awk '{print $NF}')
    [ -z "$PACKAGES_PATHS" ] && { echo "No Packages.gz paths found"; exit 1; }

    TOTAL=0
    for pkg_path in $PACKAGES_PATHS; do
        local_path="$PACKAGES_DIR/$DIST_PATH/$pkg_path"
        download_file "$REPO_BASE/$DIST_PATH/$pkg_path" "$local_path" || continue
        temp_packages=$(mktemp)
        gunzip -c "$local_path" > "$temp_packages"
        DEB_LIST=$(awk '/^Filename: / {print $2}' "$temp_packages")
        rm -f "$temp_packages"
        for filename in $DEB_LIST; do
            download_file "$REPO_BASE/$filename" "$PACKAGES_DIR/$filename" || continue
            TOTAL=$((TOTAL+1))
        done
    done
    fail_ok "DEB repo synced: $TOTAL packages"
}

create_rpm_repo() {
    mkdir -p "$PACKAGES_DIR/repodata"
    fail_ok "Base structure created"

    download_file "$REPO_BASE/repodata/repomd.xml" "$PACKAGES_DIR/repodata/repomd.xml" || exit 1

    REPO_DATA_LIST=$(grep -o 'href="[^"]*"' "$PACKAGES_DIR/repodata/repomd.xml" | sed 's/href="//; s/"//')

    COUNT_RD=0
    for filename in $REPO_DATA_LIST; do
        download_file "$REPO_BASE/$filename" "$PACKAGES_DIR/$filename" || continue
    done
    fail_ok "repodata synced"

    PRIMARY_FILE=$(find "$PACKAGES_DIR/repodata" -name "*primary.xml.gz" | head -n 1)
    temp_primary=$(mktemp)
    gunzip -c "$PRIMARY_FILE" > "$temp_primary"
    RPM_LIST=$(grep -o '<location href="[^"]*"' "$temp_primary" | sed 's/<location href="//; s/"//' | grep -v '^$')
    rm -f "$temp_primary"

    COUNT=0
    for filename in $RPM_LIST; do
        download_file "$REPO_BASE/$filename" "$PACKAGES_DIR/$filename" || continue
        COUNT=$((COUNT+1))
    done
    fail_ok "RPM repo synced: $COUNT packages"
}

setup_nginx() {
    $PM install -y nginx >/dev/null 2>&1
    fail_ok "nginx installed"

    HOSTNAME=$(hostname -f)
    SERVER_IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

    if grep -qi "alt" /etc/os-release 2>/dev/null; then
        NGINX_CONF="/etc/nginx/sites-enabled.d/localrepo.conf"
    else
        NGINX_CONF="/etc/nginx/conf.d/localrepo.conf"
    fi

    cat <<EOF > "$NGINX_CONF"
server {
    listen       1337 default_server;
    listen       [::]:1337 default_server;
    server_name  ${HOSTNAME} ${SERVER_IP};
    root         ${OUTPUT_BASE_DIR};
    include /etc/nginx/default.d/*.conf;

    location / {
        allow all;
        sendfile on;
        sendfile_max_chunk 1m;
        autoindex on;
        autoindex_exact_size off;
        autoindex_format html;
        autoindex_localtime on;
    }

    error_page 404 /404.html;
    location = /40x.html { }
    error_page 500 502 503 504 /50x.html;
    location = /50x.html { }
}
EOF
    fail_ok "nginx configuration created: $NGINX_CONF"

    systemctl enable nginx >/dev/null 2>&1
    systemctl restart nginx >/dev/null 2>&1
    fail_ok "nginx enabled and running"
}

install_repo() {
    mkdir -p "$PACKAGES_DIR" "$ARCHIVES_DIR"
    fail_ok "Base directories prepared"

    detect_repo_type

    if [ "$REPO_TYPE" = "deb" ]; then
        create_deb_repo
    else
        create_rpm_repo
    fi

    setup_nginx
}

download_repo() {
    mkdir -p "$PACKAGES_DIR"
    fail_ok "Base directories prepared for download"

    detect_repo_type

    if [ "$REPO_TYPE" = "deb" ]; then
        create_deb_repo
    else
        create_rpm_repo
    fi

    fail_ok "Repository downloaded"
}

sync_repo() {
    detect_repo_type

    rm -rf $PACKAGES_DIR

    if [ "$REPO_TYPE" = "deb" ]; then
        create_deb_repo
    else
        create_rpm_repo
    fi
    fail_ok "Repository synced"
}

clean_repo() {
    rm -rf $PACKAGES_DIR
    fail_ok "Repository cleaned"
}

uninstall_repo() {
    rm -rf "$OUTPUT_BASE_DIR"

    systemctl stop nginx >/dev/null 2>&1
    systemctl disable nginx >/dev/null 2>&1

    if [ "$PM" = "apt" ]; then
        apt purge -y nginx >/dev/null 2>&1
        apt autoremove -y >/dev/null 2>&1
    else
        $PM remove -y nginx >/dev/null 2>&1
    fi

    rm -rf /etc/nginx/conf.d/localrepo.conf
    
    fail_ok "Repository and nginx removed"
}

# === Commands
command() {
    case "$1" in
        install)
            install_repo
            ;;
        download)
            download_repo
            ;;
        sync)
            sync_repo
            ;;
        clean)
            clean_repo
            ;;
        uninstall)
            uninstall_repo
            ;;
        *)
            echo ""
            echo $"Usage: $0 { install <REPO_NAME> | download <REPO_NAME> | sync <REPO_NAME> | clean | uninstall }"
            echo ""
            echo "    install   - setup local repo, nginx, and sync packages"
            echo "    download  - download new repo"
            echo "    sync      - re-download packages and metadata"
            echo "    clean     - remove all downloaded packages"
            echo "    uninstall - remove all downloaded data and packages"
            echo ""
            exit 1
            ;;
    esac
}

command "$1" "$2"
exit 0