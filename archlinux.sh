#!/bin/bash

if [ -f /etc/arch-release ] || grep -q "ID=arch" /etc/os-release 2>/dev/null; then
    mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak.$(date +%Y%m%d)
    echo "기존 미러리스트를 백업했습니다: /etc/pacman.d/mirrorlist.bak.$(date +%Y%m%d)"
    echo "Server = https://http.krfoss.org/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
    echo "미러 설정이 완료되었습니다."
    exit 0
else
    echo "이 스크립트는 아치리눅스에서만 실행할 수 있습니다."
    exit 1
fi