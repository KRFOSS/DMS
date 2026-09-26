#!/bin/bash

DMS_URL="http://http.krfoss.org"

if [ "$EUID" -ne 0 ]; then
    echo "root 권한이 필요합니다"
    exit 1
fi

if grep -qi "ubuntu" /etc/os-release; then
    USE_DEB822=false
    CODENAME=$(lsb_release -cs 2>/dev/null || grep -oP "VERSION_CODENAME=\K\w+" /etc/os-release)

    # Detect DEB822 Format
    if [[ "$CODENAME" == "noble" || "$CODENAME" > "noble" ]]; then
        USE_DEB822=true
    fi

    # Override DEB822 Format
    if [ -n "${DEB822:-}" ]; then
        if [[ "$DEB822" == "true" || "$DEB822" == "false" ]]; then
            USE_DEB822="$DEB822"
        else
            echo "DEB822 값은 true 또는 false여야 합니다" >&2
            exit 1
        fi
    fi

    echo "Ubuntu ($CODENAME) 감지"
    echo "DEB822 형식 사용: $USE_DEB822"

    # Backup original files
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.bak
    fi

    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    echo "ubuntu.sources 및 sources.list 파일이 각각 .bak 확장자로 백업되었습니다."
    echo "sources.list의 경우 존재할 경우에만 백업됩니다."

    if [ "$USE_DEB822" = true ]; then
        mkdir -p /etc/apt/sources.list.d
        if [ -f /etc/apt/sources.list ]; then
            echo "# DEB822 사용 여부가 $USE_DEB822로 확인되어 해당 파일은 더이상 사용하지 않습니다. /etc/apt/sources.list.d/ubuntu.sources 파일을 사용하세요." > /etc/apt/sources.list
        fi

        cat > /etc/apt/sources.list.d/ubuntu.sources <<EOF
Types: deb deb-src
URIs: $DMS_URL/ubuntu/
Suites: $CODENAME $CODENAME-updates $CODENAME-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb deb-src
URIs: $DMS_URL/ubuntu/
Suites: $CODENAME-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

        sleep 1
        echo "ubuntu.sources 파일이 변경되었습니다."
    else
        cat > /etc/apt/sources.list <<EOF
deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME main restricted universe multiverse
deb-src [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME main restricted universe multiverse
deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb-src [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb-src [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-security main restricted universe multiverse
deb-src [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] $DMS_URL/ubuntu/ $CODENAME-security main restricted universe multiverse
EOF

        sleep 1
        echo "sources.list 파일이 변경되었습니다."
    fi

    sleep 2
    echo "APT 캐시 삭제 및 업데이트를 진행합니다"
    if apt clean && apt update; then
        echo "미러가 ROKFOSS 분산미러로 변경되었습니다."
    fi
fi
