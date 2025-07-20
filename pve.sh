#!/bin/bash

# 스크립트가 파이프 방식으로 실행되는지 확인
is_piped=0
if [ ! -t 0 ]; then
    # 파이프로 실행 중
    is_piped=1
fi

if [ "$(id -u)" != "0" ]; then
   echo "이 스크립트는 루트 권한으로 실행해야 합니다." 1>&2
   exit 1
fi

# Proxmox VE 확인
if ! dpkg -l | grep -q pve-manager; then
    echo "이 스크립트는 Proxmox VE 환경에서만 실행할 수 있습니다."
    exit 1
fi

# 시스템 정보 확인
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

# Ceph 버전 확인
ceph_version=""
if pveversion -v | grep -q "ceph"; then
    ceph_version=$(pveversion -v | grep "ceph" | awk -F: '{print $2}' | awk -F- '{print $1}' | tr -d ' ')
    echo "감지된 Ceph 버전: $ceph_version"
fi

# 기본값 설정 - ceph 버전을 찾지 못한 경우
if [ -z "$ceph_version" ]; then
    if [ "$codename" = "bookworm" ]; then
        ceph_version="reef"  # Proxmox 8.x (bookworm)용 기본 Ceph 버전
    elif [ "$codename" = "bullseye" ]; then
        ceph_version="pacific"  # Proxmox 7.x (bullseye)용 기본 Ceph 버전
    elif [ "$codename" = "trixie" ]; then
        ceph_version="squid"  # Proxmox 9.x (trixie)용 기본 Ceph 버전
    fi
    echo "Ceph 버전을 자동 감지할 수 없어 기본값($ceph_version)을 사용합니다."
fi

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
    if [ "$ceph_version" != "quincy" ]; then
        cat >> /etc/apt/sources.list.d/ceph.list << EOF
deb https://http.krfoss.org/proxmox/debian/ceph-$ceph_version $codename no-subscription
EOF
    fi

    # quincy, squid 리포지토리는 기존대로 추가
    cat >> /etc/apt/sources.list.d/ceph.list << EOF
deb https://http.krfoss.org/proxmox/debian/ceph-quincy $codename no-subscription
deb https://http.krfoss.org/proxmox/debian/ceph-squid $codename no-subscription
EOF

    echo "✓ ceph.list 파일이 ROKFOSS 분산 미러로 업데이트되었습니다."
fi

# sources.list.d 디렉토리의 다른 .list 파일 삭제 (ceph.list 제외)
echo "기타 저장소 파일을 제거합니다..."
for file in /etc/apt/sources.list.d/*.list; do
    if [ -f "$file" ] && [ "$(basename $file)" != "ceph.list" ]; then
        # 백업 생성
        cp "$file" "${file}.bak"
        echo "✓ $(basename $file) 파일을 백업했습니다: ${file}.bak"
        
        # 파일 삭제
        rm "$file"
        echo "✓ $(basename $file) 파일이 제거되었습니다."
    fi
done

# 새로운 sources.list 파일 생성
echo "ROKFOSS 미러 소스로 sources.list 파일을 생성합니다..."
cat > /etc/apt/sources.list << EOF
deb https://http.krfoss.org/debian $codename main contrib

deb https://http.krfoss.org/debian $codename-updates main contrib

deb https://http.krfoss.org/proxmox/debian/pve $codename pve-no-subscription

# security updates
deb https://http.krfoss.org/debian-security/ $codename-security main contrib
EOF

echo "✓ 새로운 sources.list 파일이 생성되었습니다."

# APT 캐시 업데이트
echo "APT 캐시를 업데이트합니다..."
apt update

# 구독 경고창 제거 여부 확인
remove_nag="Y"  # 기본값 Y

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

# if [[ $remove_nag =~ ^[Yy]$ ]]; then
#     echo "구독 경고창을 제거합니다..."
    
#     # 원본 파일 백업
#     cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak
#     echo "✓ 원본 JS 파일을 백업했습니다: /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak"
    
#     # 경고창 비활성화
#     sed -i "s/\tExt.Msg.show/void/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
#     echo "✓ 구독 경고창이 제거되었습니다."
    
#     # pveproxy 서비스 재시작 (UI 변경사항 적용)
#     systemctl restart pveproxy
#     echo "✓ pveproxy 서비스가 재시작되었습니다."
#     echo "✓ 웹 브라우저를 새로고침하여 변경사항을 확인하세요."
# else
#     echo "구독 경고창 제거를 건너뛰었습니다."
# fi

echo "✅ Proxmox VE의 모든 저장소가 ROKFOSS 분산 미러로 성공적으로 변경되었습니다! 이제 최고의 속도로 다운로드를 즐기세요!"
