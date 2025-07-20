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

# 기존 저장소 파일 백업
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d)
    echo "✓ 기존 sources.list 파일을 백업했습니다: /etc/apt/sources.list.bak.$(date +%Y%m%d)"
    cp -r /etc/apt/sources.list.d /etc/apt/sources.list.d.bak.$(date +%Y%m%d)
    echo "✓ 기존 sources.list.d 디렉토리를 백업했습니다: /etc/apt/sources.list.d.bak.$(date +%Y%m%d)"
else
    echo "기존 sources.list 파일이 없습니다. 새로 생성합니다."
    mkdir -p /etc/apt/sources.list.d
    touch /etc/apt/sources.list
fi

# 기존 sources.list 백업
if [ -f /etc/apt/sources.list ]; then
    cp /etc/apt/sources.list /etc/apt/sources.list.bak
    echo "✓ 기존 sources.list 파일을 백업했습니다: /etc/apt/sources.list.bak"
fi

# sources.list 파일에서 미러 주소만 변경
if [ -f /etc/apt/sources.list ]; then
    echo "sources.list 파일의 미러를 ROKFOSS로 변경합니다..."
    
    # 다양한 미러 주소를 http.krfoss.org로 변경
    sed -i 's|https\?://[^/]*/debian|https://http.krfoss.org/debian|g' /etc/apt/sources.list
    sed -i 's|https\?://[^/]*/proxmox|https://http.krfoss.org/proxmox|g' /etc/apt/sources.list
    sed -i 's|https\?://[^/]*/debian-security|https://http.krfoss.org/debian-security|g' /etc/apt/sources.list
    
    echo "✓ sources.list 파일이 ROKFOSS 미러로 업데이트되었습니다."
fi

# sources.list.d 디렉토리의 .list 파일들도 동일하게 처리
echo "sources.list.d 디렉토리의 저장소 파일들을 업데이트합니다..."
for file in /etc/apt/sources.list.d/*.list; do
    if [ -f "$file" ]; then
        # 백업 생성
        cp "$file" "${file}.bak"
        echo "✓ $(basename $file) 파일을 백업했습니다: ${file}.bak"
        
        # 미러 주소 변경
        sed -i 's|https\?://[^/]*/debian|https://http.krfoss.org/debian|g' "$file"
        sed -i 's|https\?://[^/]*/proxmox|https://http.krfoss.org/proxmox|g' "$file"
        sed -i 's|https\?://[^/]*/debian-security|https://http.krfoss.org/debian-security|g' "$file"
        
        echo "✓ $(basename $file) 파일이 ROKFOSS 미러로 업데이트되었습니다."
    fi
done

for file in /etc/apt/sources.list.d/*.sources; do
    if [ -f "$file" ]; then
        # 백업 생성
        cp "$file" "${file}.bak"
        echo "✓ $(basename $file) 파일을 백업했습니다: ${file}.bak"
        
        # 미러 주소 변경
        sed -i 's|https\?://[^/]*/debian|https://http.krfoss.org/debian|g' "$file"
        sed -i 's|https\?://[^/]*/proxmox|https://http.krfoss.org/proxmox|g' "$file"
        sed -i 's|https\?://[^/]*/debian-security|https://http.krfoss.org/debian-security|g' "$file"
        
        echo "✓ $(basename $file) 파일이 ROKFOSS 미러로 업데이트되었습니다."
    fi
done


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
