#!/bin/bash

# 스크립트가 파이프 방식으로 실행되는지 확인
is_piped=0
if [ ! -t 0 ]; then
    # 파이프로 실행 중
    is_piped=1
fi

# 루트 권한 확인
if [ "$(id -u)" != "0" ]; then
    echo "이 스크립트는 루트 권한으로 실행해야 합니다." 1>&2
    exit 1
fi

# Proxmox VE 확인
if ! dpkg -l | grep -q pve-manager; then
    echo "이 스크립트는 Proxmox VE 환경에서만 실행할 수 있습니다."
    exit 1
fi

# 시스템 정보 확인 (코드네임 감지)
codename=$(grep "VERSION_CODENAME=" /etc/os-release | cut -d= -f2 | tr -d '"')
if [ -z "$codename" ]; then
    # 코드명을 찾을 수 없는 경우 대체 방법 시도
    if grep -q "bullseye" /etc/os-release; then
        codename="bullseye"
    elif grep -q "bookworm" /etc/os-release; then
        codename="bookworm"
    elif grep -q "trixie" /etc/os-release; then
        codename="trixie"
    else
        echo "지원되지 않는 Debian 버전입니다."
        exit 1
    fi
fi

echo "Proxmox VE ($codename) 미러 소스를 변경합니다..."

# Ceph 버전 확인 및 기본값 설정
ceph_version="squid"  # 기본 Ceph 버전 (Proxmox 9.x trixie 기준), Proxmox 8.x
if pveversion -v | grep -E "^ceph:"; then
    ceph_version=$(pveversion -v | grep -E "^ceph:" | awk -F: '{print $2}' | awk -F- '{print $1}' | tr -d ' ')
    echo "감지된 Ceph 버전: $ceph_version"
fi

if [ -z "$ceph_version" ]; then
    if [ "$codename" = "bookworm" ]; then
        ceph_version="reef"   # Proxmox 8.x (bookworm)용 기본 Ceph 버전
    elif [ "$codename" = "bullseye" ]; then
        ceph_version="pacific"   # Proxmox 7.x (bullseye)용 기본 Ceph 버전
    elif [ "$codename" = "trixie" ]; then
        ceph_version="squid"   # Proxmox 9.x (trixie)용 기본 Ceph 버전
    fi
    echo "Ceph 버전을 자동 감지할 수 없어 기본값($ceph_version)을 사용합니다."
fi

# Proxmox VE 버전이 베타/테스트 버전인지 확인 (예: 9.0.0~8)
IS_PVE_BETA=false
if pveversion -v | grep -q "~"; then
    IS_PVE_BETA=true
    echo "Proxmox VE 베타/테스트 버전이 감지되었습니다. pve-test 저장소를 사용합니다."
fi

# Debian 13 (trixie) 이상 버전에서 DEB822 형식 사용 여부 결정
USE_DEB822_FORMAT=false
if [[ "$codename" == "trixie" || "$codename" > "trixie" ]]; then
    USE_DEB822_FORMAT=true
    echo "Debian $codename 감지: DEB822 형식 사용"
fi

# 기존 파일 백업 디렉토리 생성
mkdir -p /etc/apt

if [ "$USE_DEB822_FORMAT" = true ]; then
    # DEB822 형식 파일 경로 정의
    DEBIAN_SOURCE_FILE="/etc/apt/sources.list.d/debian.sources"
    PROXMOX_SOURCE_FILE="/etc/apt/sources.list.d/proxmox.sources"
    CEPH_SOURCE_FILE="/etc/apt/sources.list.d/ceph.sources"

    DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.gpg"
    # Proxmox VE 및 Ceph 저장소에 사용될 키링 경로 (일반적으로 동일)
    PVE_KEYRING_PATH="/etc/apt/trusted.gpg.d/proxmox-release-${codename}.gpg"

    # Proxmox 키링 파일 존재 여부 확인 및 경고
    if [ ! -f "$PVE_KEYRING_PATH" ]; then
        echo "경고: Proxmox VE 키링 파일 ($PVE_KEYRING_PATH)을 찾을 수 없습니다."
        echo "APT 업데이트 시 서명 오류가 발생할 수 있습니다. Proxmox VE 설치가 올바른지 확인하거나 수동으로 키를 가져와야 할 수 있습니다."
    fi

    echo "DEB822 형식으로 Proxmox VE 저장소 파일을 생성합니다..."
    mkdir -p /etc/apt/sources.list.d

    # 기존 sources.list 백업 및 비활성화
    if [ -f /etc/apt/sources.list ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d)
        echo "# 이 파일은 비활성화되었습니다. DEB822 형식이 /etc/apt/sources.list.d/ 에 사용됨" > /etc/apt/sources.list
        echo "기존 /etc/apt/sources.list를 백업하고 비활성화했습니다."
    fi

    # sources.list.d 디렉토리의 기존 .list 또는 .sources 파일 백업 및 제거
    echo "기존 .list 및 .sources 저장소 파일을 백업하고 제거합니다..."
    for file in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        if [ -f "$file" ]; then
            BACKUP_LIST_FILE="/etc/apt/sources.list.d/$(basename "$file").bak.$(date +%Y%m%d)"
            cp "$file" "$BACKUP_LIST_FILE"
            echo "✓ $(basename "$file") 파일을 백업했습니다: $BACKUP_LIST_FILE"
            rm "$file"
            echo "✓ $(basename "$file") 파일이 제거되었습니다."
        fi
    done

    # 1. Debian 기본 저장소 파일 생성 (debian.sources)
    cat > "$DEBIAN_SOURCE_FILE" << EOF
# ROKFOSS Debian 기본 저장소
Types: deb deb-src
URIs: https://http.krfoss.org/debian/
Suites: $codename $codename-updates $codename-backports
Components: main contrib non-free non-free-firmware
Signed-By: $DEBIAN_KEYRING

Types: deb deb-src
URIs: https://http.krfoss.org/debian-security/
Suites: $codename-security
Components: main contrib non-free non-free-firmware
Signed-By: $DEBIAN_KEYRING
EOF
    echo "✓ $DEBIAN_SOURCE_FILE 파일이 성공적으로 생성되었습니다."

    # 2. Proxmox VE 저장소 파일 생성 (proxmox.sources)
    PVE_COMPONENTS="pve-no-subscription"
    if [ "$IS_PVE_BETA" = true ]; then
        PVE_COMPONENTS="pve-test"
    fi

    cat > "$PROXMOX_SOURCE_FILE" << EOF
# ROKFOSS Proxmox VE 저장소
Types: deb
URIs: https://http.krfoss.org/proxmox/debian/pve
Suites: $codename
Components: $PVE_COMPONENTS
Signed-By: $PVE_KEYRING_PATH
EOF
    echo "✓ $PROXMOX_SOURCE_FILE 파일이 성공적으로 생성되었습니다."

    # 3. Ceph 저장소 파일 생성 (ceph.sources)
    cat > "$CEPH_SOURCE_FILE" << EOF
# ROKFOSS Ceph 저장소
EOF

    # 2. Proxmox VE Ceph 저장소 파일 생성 (ceph.sources)
    CEPH_COMPONENTS="no-subscription"
    if [ "$IS_PVE_BETA" = true ]; then
        CEPH_COMPONENTS="test"
    fi

    # ceph_version이 quincy가 아닐 때만 해당 Ceph 리포지토리 추가
    cat >> "$CEPH_SOURCE_FILE" << EOF
Types: deb
URIs: https://http.krfoss.org/proxmox/debian/ceph-$ceph_version
Suites: $codename
Components: no-subscription
Signed-By: $PVE_KEYRING_PATH
EOF
    echo "✓ $CEPH_SOURCE_FILE 파일이 성공적으로 생성되었습니다."

else
    # 기존 Legacy 형식 사용 (trixie 미만 버전)
    echo "Legacy 형식으로 sources.list 파일을 ROKFOSS 미러 주소로 변경합니다..."

    # 기존 sources.list 백업
    BACKUP_FILE="/etc/apt/sources.list.bak.$(date +%Y%m%d)"
    cp /etc/apt/sources.list "$BACKUP_FILE"
    echo "기존 sources.list를 $BACKUP_FILE로 백업했습니다."

    # ceph.list 파일 업데이트
    if [ -f /etc/apt/sources.list.d/ceph.list ]; then
        echo "Ceph 저장소를 ROKFOSS 분산 미러로 업데이트합니다..."

        # 백업 파일 생성
        cp /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak
        echo "✓ 기존 ceph.list 파일을 백업했습니다: /etc/apt/sources.list.d/ceph.list.bak"

        # ceph.list 파일 내용 교체
        cat > /etc/apt/sources.list.d/ceph.list << EOF
# ROKFOSS Ceph 분산 미러로 교체됨
EOF

        # ceph_version이 quincy가 아닐 때만 ceph-$ceph_version 리포지토리를 추가
        cat >> /etc/apt/sources.list.d/ceph.list << EOF
deb https://http.krfoss.org/proxmox/debian/ceph-$ceph_version $codename no-subscription
EOF

        echo "✓ ceph.list 파일이 ROKFOSS 분산 미러로 업데이트되었습니다."
    fi

    # sources.list.d 디렉토리의 다른 .list 파일 삭제 (ceph.list 제외)
    echo "기타 저장소 파일을 제거합니다..."
    for file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "ceph.list" ]; then
            # 백업 생성
            cp "$file" "${file}.bak"
            echo "✓ $(basename "$file") 파일을 백업했습니다: ${file}.bak"

            # 파일 삭제
            rm "$file"
            echo "✓ $(basename "$file") 파일이 제거되었습니다."
        fi
    done

    # 새로운 sources.list 파일 생성
    echo "ROKFOSS 미러 소스로 sources.list 파일을 생성합니다..."
    PVE_COMPONENTS="pve-no-subscription"
    if [ "$IS_PVE_BETA" = true ]; then
        PVE_COMPONENTS="pve-test"
    fi

    cat > /etc/apt/sources.list << EOF
deb https://http.krfoss.org/debian $codename main contrib

deb https://http.krfoss.org/debian $codename-updates main contrib

deb https://http.krfoss.org/proxmox/debian/pve $codename $PVE_COMPONENTS

# security updates
deb https://http.krfoss.org/debian-security/ $codename-security main contrib
EOF

    echo "✓ 새로운 sources.list 파일이 생성되었습니다."
fi

# APT 캐시 업데이트
echo "APT 캐시를 업데이트합니다..."
apt update

# 구독 경고창 제거 여부 확인
remove_nag="Y"   # 기본값 Y

# 파이프로 실행되지 않은 경우에만 입력 요청
if [ $is_piped -eq 0 ]; then
    echo ""
    read -p "Proxmox VE 웹 인터페이스에서 구독 경고창을 제거하시겠습니까? [Y/n]: " user_input
    if [ -n "$user_input" ]; then
        remove_nag=$user_input
    fi
else
    # 파이프로 실행된 경우 자동 진행 안내
    echo ""
    echo "curl 파이프 방식으로 실행 중 - 자동으로 구독 경고창을 제거합니다."
    echo "구독 경고창 제거를 원하지 않으면, 아래 명령으로 복원할 수 있습니다:"
    echo "mv /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && systemctl restart pveproxy"
fi

# 사용자 요청에 따라 구독 경고창 제거 로직은 주석 처리된 상태로 유지합니다.
# if [[ $remove_nag =~ ^[Yy]$ ]]; then
#     echo "구독 경고창을 제거합니다..."
#     cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
#     echo "✓ 원본 JS 파일을 백업했습니다: /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak"
#     sed -i "s/\tExt.Msg.show/void/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
#     echo "✓ 구독 경고창이 제거되었습니다."
#     systemctl restart pveproxy
#     echo "✓ pveproxy 서비스가 재시작되었습니다."
#     echo "✓ 웹 브라우저를 새로고침하여 변경사항을 확인하세요."
# else
#     echo "구독 경고창 제거를 건너뛰었습니다."
# fi

echo "✅ Proxmox VE의 모든 저장소가 ROKFOSS 분산 미러로 성공적으로 변경되었습니다! 이제 최고의 속도로 다운로드를 즐기세요!"
