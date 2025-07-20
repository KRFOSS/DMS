#!/bin/bash
set -e

# CentOS 여부 확인
if ! { [ -f /etc/centos-release ] || grep -qi 'CentOS' /etc/os-release 2>/dev/null; }; then
    echo "이 스크립트는 CentOS 계열에서만 동작합니다!! 다른 운영체제에서는 사용할 수 없습니다."
    exit 1
fi

# 버전 판별
VERSION_ID=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release)
if [[ ${VERSION_ID%%.*} -ge 10 ]]; then
    KEY_SUFFIX="-SHA256"
else
    KEY_SUFFIX=""
fi
KEY="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial${KEY_SUFFIX}"

REPO_PATH="/etc/yum.repos.d/centos.repo"

# 새 repo 생성
cat > "$REPO_PATH" <<EOF
[baseos]
name=CentOS Stream \$releasever - BaseOS
baseurl=https://http.krfoss.org/centos-stream/\$stream/BaseOS/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1

[baseos-debuginfo]
name=CentOS Stream \$releasever - BaseOS - Debug
baseurl=https://http.krfoss.org/centos-stream/\$stream/BaseOS/\$basearch/debug/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[baseos-source]
name=CentOS Stream \$releasever - BaseOS - Source
baseurl=https://http.krfoss.org/centos-stream/\$stream/BaseOS/Source/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[appstream]
name=CentOS Stream \$releasever - AppStream
baseurl=https://http.krfoss.org/centos-stream/\$stream/AppStream/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=1

[appstream-debuginfo]
name=CentOS Stream \$releasever - AppStream - Debug
baseurl=https://http.krfoss.org/centos-stream/\$stream/AppStream/\$basearch/debug/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[appstream-source]
name=CentOS Stream \$releasever - AppStream - Source
baseurl=https://http.krfoss.org/centos-stream/\$stream/AppStream/Source/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[crb]
name=CentOS Stream \$releasever - CRB
baseurl=https://http.krfoss.org/centos-stream/\$stream/CRB/\$basearch/os/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
countme=1
enabled=0

[crb-debuginfo]
name=CentOS Stream \$releasever - CRB - Debug
baseurl=https://http.krfoss.org/centos-stream/\$stream/CRB/\$basearch/debug/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0

[crb-source]
name=CentOS Stream \$releasever - CRB - Source
baseurl=https://http.krfoss.org/centos-stream/\$stream/CRB/Source/
gpgkey=$KEY
gpgcheck=1
repo_gpgcheck=0
metadata_expire=6h
enabled=0
EOF

dnf clean all
dnf makecache
echo "centos.repo가 ROKFOSS 분산미러로 설정되었습니다."
