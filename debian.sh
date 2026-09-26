#!/bin/bash

DMS_URL="http://http.krfoss.org"

if [ "$EUID" -ne 0 ]; then
    echo "root 권한이 필요합니다"
    exit 1
fi

if grep -qi 'debian' /etc/os-release; then
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}"
    VERSION_NUMBER="${VERSION_ID%%.*}"
    USE_DEB822=false

    if [ -z "$CODENAME" ]; then
        echo "Debian 코드명을 확인할 수 없습니다" >&2
        exit 1
    fi

    # Detect DEB822 Format
    if [[ "$VERSION_NUMBER" =~ ^[0-9]+$ ]] && [ "$VERSION_NUMBER" -ge 13 ]; then
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

    if [[ "$VERSION_NUMBER" =~ ^[0-9]+$ ]] && [ "$VERSION_NUMBER" -ge 12 ]; then
        COMPONENTS="main contrib non-free non-free-firmware"
    else
        COMPONENTS="main contrib non-free"
    fi

    echo "Debian ($CODENAME) 감지"
    echo "DEB822 형식 사용: $USE_DEB822"

    # Backup original files
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak
    fi

    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    echo "debian.sources 및 sources.list 파일이 각각 .bak 확장자로 백업되었습니다."
    echo "sources.list의 경우 존재할 경우에만 백업됩니다."

    if [ "$USE_DEB822" = true ]; then
        mkdir -p /etc/apt/sources.list.d
        if [ -f /etc/apt/sources.list ]; then
            echo "# DEB822 사용 여부가 $USE_DEB822로 확인되어 해당 파일은 더이상 사용하지 않습니다. /etc/apt/sources.list.d/debian.sources 파일을 사용하세요." > /etc/apt/sources.list
        fi

        cat > /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb deb-src
URIs: $DMS_URL/debian/
Suites: $CODENAME $CODENAME-updates $CODENAME-backports
Components: $COMPONENTS
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: $DMS_URL/debian-security/
Suites: $CODENAME-security
Components: $COMPONENTS
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

        sleep 1
        echo "debian.sources 파일이 변경되었습니다."
    else
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            echo "# sources.list 파일을 사용하므로 비활성화되었습니다." > /etc/apt/sources.list.d/debian.sources
        fi

        cat > /etc/apt/sources.list <<EOF
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME $COMPONENTS
deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME $COMPONENTS
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME-updates $COMPONENTS
deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME-updates $COMPONENTS
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME-backports $COMPONENTS
deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian/ $CODENAME-backports $COMPONENTS
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian-security/ $CODENAME-security $COMPONENTS
deb-src [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] $DMS_URL/debian-security/ $CODENAME-security $COMPONENTS
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
