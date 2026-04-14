#!/bin/bash

BACKUP_FILES=("/etc/pacman.d/mirrorlist" "/etc/pacman.d/cachyos-mirrorlist" "/etc/pacman.d/cachyos-v3-mirrorlist" "/etc/pacman.d/cachyos-v4-mirrorlist")
MIRROR_URL="https://http.krfoss.org"

if [ "$EUID" -ne 0 ]; then
    echo "이 스크립트는 root 권한으로만 실행할 수 있습니다."
    exit 1
else
    if [ -f /etc/os-release ] && grep -q "ID=cachyos" /etc/os-release; then
        if ls /etc/pacman.d/mirrorlist /etc/pacman.d/cachyos* &>/dev/null; then
            for file in "${BACKUP_FILES[@]}"; do
                if [ -f "$file" ]; then
                    dir=$(dirname "$file")
                    base=$(basename "$file")

                    cp "$file" "$dir/.${base}k"
                fi
            done

            echo "기존 미러리스트 파일이 /etc/pacman.d 디렉토리에 숨김 파일로 백업되었습니다."
            
            printf "Arch Linux 미러리스트 파일도 교체할까요? (Yy/Nn): " > /dev/tty
            read answer < /dev/tty
            
            case "$answer" in
                [Yy]* )
                    echo "Server = ${MIRROR_URL}/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
                ;;
                [Nn]* )
                    echo "Arch Linux 미러리스트 파일은 변경되지 않았습니다."
                ;;
            esac

            # Cachyos Mirrorlist
            echo "Server = ${MIRROR_URL}/cachyos/repo/\$arch/\$repo" > /etc/pacman.d/cachyos-mirrorlist

            # Cachyos V3 Mirrorlist
            echo "Server = ${MIRROR_URL}/cachyos/repo/\$arch_v3/\$repo" > /etc/pacman.d/cachyos-v3-mirrorlist

            # Cachyos V4 Mirrorlist
            echo "Server = ${MIRROR_URL}/cachyos/repo/\$arch_v4/\$repo" > /etc/pacman.d/cachyos-v4-mirrorlist
            
            # Disable systemd timer unit (cachyos-rate-mirrors.timer)
            systemctl disable cachyos-rate-mirrors.timer --now

            if pacman -Scc --noconfirm &>/dev/null && pacman -Sy; then
                echo "패키지 데이터베이스가 업데이트되었습니다."
            else
                echo "패키지 데이터베이스 업데이트에 실패했습니다. 네트워크 및 미러 설정을 확인하세요."
            fi

            echo "================================================"
            echo " * 미러 변경이 완료되었습니다."
            echo " * 미러 변경을 방지하기 위해 cachyos-rate-mirrors 타이머 유닛이 비활성화되었으며, 다음 명령어로 다시 활성화할 수 있습니다:"
            echo "   systemctl enable cachyos-rate-mirrors.timer --now"
            echo ""
            echo " * 서명이 올바르지 않다고 표시될 경우 'pacman -Sy'를 다시 실행하며 해결할 수 있습니다."
            echo "   문제 발생이 지속될 경우 https://report.krfoss.org 에 오류를 제보해주세요."
            echo "================================================"
        else
            echo "미러리스트 파일이 /etc/pacman.d 디렉토리에 존재하지 않습니다."
            exit 1
        fi 
    else
        echo "이 스크립트는 CachyOS에서만 실행할 수 있습니다."
        exit 1
    fi
fi
