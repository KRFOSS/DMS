#!/bin/bash
set -e

# AlmaLinux 여부 확인
if ! grep -qi 'AlmaLinux' /etc/os-release 2>/dev/null; then
    echo "이 스크립트는 AlmaLinux에서만 동작합니다!!"
    exit 1
fi

# AlmaLinux 버전 확인
VERSION_ID=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release)
REPO_PATH="/etc/yum.repos.d/almalinux.repo"
BACKUP_PATH="${REPO_PATH}.bak.$(date +%Y%m%d%H%M%S)"
KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-AlmaLinux-${VERSION_ID%%.*}"


# 버전별 URL 설정
if [ "${VERSION_ID%%.*}" = "10" ]; then
    BASE_URL="https://http.krfoss.org/almalinux-kitten/10-kitten"
else
    BASE_URL="https://http.krfoss.org/almalinux/\$releasever"
fi

# 기존 repo 파일 백업
for f in /etc/yum.repos.d/*.repo; do
    [ -e "$f" ] && cp "$f" "${f}.bak.$(date +%Y%m%d)"
    echo "기존 repo 파일을 백업했습니다: ${f}.bak.$(date +%Y%m%d)"
done

rm -f /etc/yum.repos.d/*.repo

# 새 repo 파일 작성
cat > "$REPO_PATH" <<EOF
[baseos]
name=AlmaLinux \$releasever - BaseOS
baseurl=$BASE_URL/BaseOS/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=1
countme=1
metadata_expire=6h

[appstream]
name=AlmaLinux \$releasever - AppStream
baseurl=$BASE_URL/AppStream/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=1
countme=1
metadata_expire=6h

[crb]
name=AlmaLinux \$releasever - CRB
baseurl=$BASE_URL/CRB/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[extras]
name=AlmaLinux \$releasever - Extras
baseurl=$BASE_URL/extras/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[highavailability]
name=AlmaLinux \$releasever - HighAvailability
baseurl=$BASE_URL/HighAvailability/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[nfv]
name=AlmaLinux \$releasever - NFV
baseurl=$BASE_URL/NFV/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[plus]
name=AlmaLinux \$releasever - Plus
baseurl=$BASE_URL/plus/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[resilientstorage]
name=AlmaLinux \$releasever - ResilientStorage
baseurl=$BASE_URL/ResilientStorage/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[rt]
name=AlmaLinux \$releasever - RT
baseurl=$BASE_URL/RT/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[sap]
name=AlmaLinux \$releasever - SAP
baseurl=$BASE_URL/SAP/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[saphana]
name=AlmaLinux \$releasever - SAPHANA
baseurl=$BASE_URL/SAPHANA/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h

[kitten]
name=AlmaLinux \$releasever - Kitten
baseurl=$BASE_URL/kitten/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h
EOF

# 캐시 초기화 및 갱신
dnf clean all
dnf makecache

if [ "${VERSION_ID%%.*}" = "10" ]; then
    echo "AlmaLinux 10-kitten 저장소가 ROKFOSS 분산미러로 변경되었습니다."
else
    echo "AlmaLinux ${VERSION_ID} 저장소가 ROKFOSS 분산미러로 변경되었습니다."
fi