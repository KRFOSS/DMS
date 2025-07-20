#!/bin/bash
set -e

major_ver=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2); print $2}' /etc/os-release | cut -d. -f1)

if [[ "$major_ver" -ge 9 ]]; then
    GPGKEY="/etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9"
else
    GPGKEY="/etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial"
fi

# 기존 repo 파일 백업
for f in /etc/yum.repos.d/*.repo; do
    [ -e "$f" ] && cp "$f" ".${f}.bak.$(date +%Y%m%d)"
    echo "기존 repo 파일을 백업했습니다: ${f}.bak.$(date +%Y%m%d)"
done

rm -f /etc/yum.repos.d/*.repo

cat > /etc/yum.repos.d/rokfoss.repo <<EOF
[appstream]
name=Rocky Linux \$releasever - AppStream
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever
baseurl=https://http.krfoss.org/rocky/\$releasever/AppStream/\$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file://$GPGKEY

[baseos]
name=Rocky Linux \$releasever - BaseOS
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=BaseOS-\$releasever
baseurl=https://http.krfoss.org/rocky/\$releasever/BaseOS/\$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file://$GPGKEY

[baseos-debuginfo]
name=Rocky Linux \$releasever - BaseOS - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=BaseOS-\$releasever-debug
baseurl=https://http.krfoss.org/rocky/\$releasever/BaseOS/\$basearch/debug/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[appstream-debuginfo]
name=Rocky Linux \$releasever - AppStream - Source
#mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=\$basearch&repo=AppStream-\$releasever-debug
baseurl=https://http.krfoss.org/rocky/\$releasever/AppStream/\$basearch/debug/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[ha-debuginfo]
name=Rocky Linux \$releasever - High Availability - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/HighAvailability/\$basearch/debug/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[powertools-debuginfo]
name=Rocky Linux \$releasever - PowerTools - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/PowerTools/\$basearch/debug/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[resilient-storage-debuginfo]
name=Rocky Linux \$releasever - Resilient Storage - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/ResilientStorage/\$basearch/debug/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[devel]
name=Rocky Linux \$releasever - Devel WARNING! FOR BUILDROOT AND KOJI USE
baseurl=https://http.krfoss.org/rocky/\$releasever/Devel/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[extras]
name=Rocky Linux \$releasever - Extras
baseurl=https://http.krfoss.org/rocky/\$releasever/extras/\$basearch/os/
gpgcheck=1
enabled=1
countme=1
gpgkey=file://$GPGKEY

[ha]
name=Rocky Linux \$releasever - HighAvailability
baseurl=https://http.krfoss.org/rocky/\$releasever/HighAvailability/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[media-baseos]
name=Rocky Linux \$releasever - Media - BaseOS
baseurl=file:///media/Rocky/BaseOS
        file:///media/cdrom/BaseOS
        file:///media/cdrecorder/BaseOS
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[media-appstream]
name=Rocky Linux \$releasever - Media - AppStream
baseurl=file:///media/Rocky/AppStream
        file:///media/cdrom/AppStream
        file:///media/cdrecorder/AppStream
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[nfv]
name=Rocky Linux \$releasever - NFV
baseurl=https://http.krfoss.org/rocky/\$releasever/nfv/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[plus]
name=Rocky Linux \$releasever - Plus
baseurl=https://http.krfoss.org/rocky/\$releasever/plus/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[powertools]
name=Rocky Linux \$releasever - PowerTools
baseurl=https://http.krfoss.org/rocky/\$releasever/PowerTools/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[rt]
name=Rocky Linux \$releasever - Realtime
baseurl=https://http.krfoss.org/rocky/\$releasever/RT/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[resilient-storage]
name=Rocky Linux \$releasever - ResilientStorage
baseurl=https://http.krfoss.org/rocky/\$releasever/ResilientStorage/\$basearch/os/
gpgcheck=1
enabled=0
countme=1
gpgkey=file://$GPGKEY

[baseos-source]
name=Rocky Linux \$releasever - BaseOS - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/BaseOS/source/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[appstream-source]
name=Rocky Linux \$releasever - AppStream - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/AppStream/source/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[ha-source]
name=Rocky Linux \$releasever - High Availability - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/HighAvailability/source/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[powertools-source]
name=Rocky Linux \$releasever - PowerTools - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/PowerTools/source/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY

[resilient-storage-source]
name=Rocky Linux \$releasever - Resilient Storage - Source
baseurl=https://http.krfoss.org/rocky/\$releasever/ResilientStorage/source/tree/
gpgcheck=1
enabled=0
gpgkey=file://$GPGKEY
EOF

dnf clean all
dnf makecache
