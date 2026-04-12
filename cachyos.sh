#!/bin/bash

BACKUP_FILES=("/etc/pacman.d/mirrorlist" "/etc/pacman.d/cachyos-mirrorlist" "/etc/pacman.d/cachyos-v3-mirrorlist" "/etc/pacman.d/cachyos-v4-mirrorlist")

if [ "$EUID" -ne 0 ]; then
    echo "이 스크립트는 root 권한으로만 실행할 수 있습니다."
    exit 1
else
    if [ -f /etc/os-release ] && grep -q "ID=cachyos" /etc/os-release; then
        if ls /etc/pacman.d/mirrorlist /etc/pacman.d/cachyos* &>/dev/null; then
            for file in "${BACKUP_FILES[@]}"; do
                if [ -f "$file" ]; then
                    cp "$file" ."$file.bak"
                fi
            done

            echo "기존 미러리스트 파일이 /etc/pacman.d 디렉토리에 백업되었습니다."
            
            read -p "Arch Linux 미러리스트 파일도 교체할까요? (Yy/Nn): " answer
            
            case "$answer" in
                [Yy]* )
                    echo "Server = https://mirror.wane.kr/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
                ;;
                [Nn]* )
                    echo "Arch Linux 미러리스트 파일은 변경되지 않았습니다."
                ;;
            esac

            # Cachyos Mirrorlist
            echo "Server = https://mirror.wane.kr/cachyos/repo/\$arch/\$repo" > /etc/pacman.d/cachyos-mirrorlist

            # Cachyos V3 Mirrorlist
            echo "Server = https://mirror.wane.kr/cachyos/repo/\$arch_v3/\$repo" > /etc/pacman.d/cachyos-v3-mirrorlist

            # Cachyos V4 Mirrorlist
            echo "Server = https://mirror.wane.kr/cachyos/repo/\$arch_v4/\$repo" > /etc/pacman.d/cachyos-v4-mirrorlist
            
            # Disable systemd timer unit (cachyos-rate-mirrors.timer)
            systemctl disable cachyos-rate-mirrors.timer --now

            if pacman -Scc --noconfirm &>/dev/null && pacman -Sy; then
                echo "패키지 데이터베이스가 업데이트되었습니다."
            else
                echo "패키지 데이터베이스 업데이트에 실패했습니다. 네트워크 및 미러 설정을 확인하세요."
            fi

            echo "================================================"
            echo " * 미러 변경이 완료되었습니다."
            echo " * 미러 고정을 위해 cachyos-rate-mirrors 타이머 유닛이 비활성화되었으며, 다음 명령어로 다시 활성화할 수 있습니다:"
            echo "   systemctl enable cachyos-rate-mirrors.timer --now"
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
