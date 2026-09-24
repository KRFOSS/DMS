#!/bin/bash

DMS_URL="http://http.krfoss.org"

if [ "$EUID" -ne 0 ]; then
    echo "root 권한이 필요합니다"
    exit 1
fi

if grep -q '^ID=kali$' /etc/os-release; then
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}"
    CODENAME="${CODENAME:-kali-rolling}"
    VERSION_NUMBER="${VERSION_ID%%.*}"
    RELEASE_NUMBER="${VERSION_ID#*.}"
    USE_DEB822=false

    # Detect DEB822 Format
    if [ -f /etc/apt/sources.list.d/kali.sources ] ||
       { [[ "$VERSION_NUMBER" =~ ^[0-9]{4}$ && "$RELEASE_NUMBER" =~ ^[0-9]+$ ]] &&
         { [ "$VERSION_NUMBER" -gt 2026 ] ||
           { [ "$VERSION_NUMBER" -eq 2026 ] && [ "$RELEASE_NUMBER" -ge 2 ]; }; }; then
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

    echo "Kali Linux ($CODENAME) 감지"
    echo "DEB822 형식 사용: $USE_DEB822"

    # Backup original files
    if [ -f /etc/apt/sources.list.d/kali.sources ]; then
        cp /etc/apt/sources.list.d/kali.sources /etc/apt/sources.list.d/kali.sources.bak
    fi

    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    echo "kali.sources 및 sources.list 파일이 각각 .bak 확장자로 백업되었습니다."
    echo "sources.list의 경우 존재할 경우에만 백업됩니다."

    if [ "$USE_DEB822" = true ]; then
        mkdir -p /etc/apt/sources.list.d
        if [ -f /etc/apt/sources.list ]; then
            echo "# DEB822 사용 여부가 $USE_DEB822로 확인되어 해당 파일은 더이상 사용하지 않습니다. /etc/apt/sources.list.d/kali.sources 파일을 사용하세요." > /etc/apt/sources.list
        fi

        cat > /etc/apt/sources.list.d/kali.sources <<EOF
Types: deb deb-src
URIs: $DMS_URL/kali/
Suites: $CODENAME
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF

        sleep 1
        echo "kali.sources 파일이 변경되었습니다."
    else
        if [ -f /etc/apt/sources.list.d/kali.sources ]; then
            echo "# sources.list 파일을 사용하므로 비활성화되었습니다." > /etc/apt/sources.list.d/kali.sources
        fi

        cat > /etc/apt/sources.list <<EOF
deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] $DMS_URL/kali/ $CODENAME main contrib non-free non-free-firmware
deb-src [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] $DMS_URL/kali/ $CODENAME main contrib non-free non-free-firmware
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
