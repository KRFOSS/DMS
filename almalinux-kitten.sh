#!/bin/bash
set -euo pipefail

# 두 스크립트는 다운로드 후 단독으로 실행할 수 있도록 독립적으로 유지합니다.
CHANNEL=kitten
ID= NAME= PRETTY_NAME= VERSION_ID=
if [ ! -r /etc/os-release ]; then
    echo "배포판 정보를 읽을 수 없습니다." >&2
    exit 1
fi
. /etc/os-release
if [ "$ID" != almalinux ]; then
    echo "이 스크립트는 AlmaLinux에서만 동작합니다." >&2
    exit 1
fi
case "$NAME" in
    "AlmaLinux Kitten") detected=kitten ;;
    "AlmaLinux")
        if [[ "$PRETTY_NAME" == *Kitten* ]]; then
            echo "배포판 정보가 일치하지 않습니다. 저장소를 변경하지 않습니다." >&2
            exit 1
        fi
        detected=stable ;;
    *) echo "AlmaLinux 종류를 확인할 수 없습니다." >&2; exit 1 ;;
esac
if [ "$detected" != "$CHANNEL" ]; then
    echo "배포판과 스크립트가 다릅니다. 정식 버전은 almalinux.sh, Kitten은 almalinux-kitten.sh를 사용하세요." >&2
    exit 1
fi
if [ "${VERSION_ID%%.*}" != 10 ]; then
    echo "이 스크립트는 AlmaLinux Kitten 10 전용입니다." >&2
    exit 1
fi
if [ "$EUID" -ne 0 ]; then
    echo "root 권한으로 실행하세요." >&2
    exit 1
fi
command -v dnf >/dev/null
BASE_URL='https://http.krfoss.org/almalinux-kitten/10-kitten'

# 공식 AlmaLinux 파일만 처리합니다. 외부 저장소 파일은 보존합니다.
shopt -s nullglob
repos=(/etc/yum.repos.d/almalinux*.repo)
if [ "${#repos[@]}" -eq 0 ]; then
    echo "AlmaLinux 저장소 파일이 없습니다. 공식 repos 패키지를 먼저 복원하세요." >&2
    exit 1
fi
workdir=$(mktemp -d /etc/yum.repos.d/.almalinux-mirror.XXXXXXXX)
applying=0
cleanup() {
    status=$?
    trap - EXIT
    if [ "$status" -ne 0 ] && [ "$applying" -eq 1 ]; then
        echo "변경에 실패하여 기존 저장소 설정을 복원합니다: $workdir" >&2
        for repo in "${repos[@]}"; do
            cp -p -- "$workdir/${repo##*/}.bak" "$repo" || true
        done
    fi
    # 성공 시에도 수동 복구를 위해 백업을 남깁니다.
    exit "$status"
}
trap cleanup EXIT

for repo in "${repos[@]}"; do
    cp -p -- "$repo" "$workdir/${repo##*/}.bak"
    # 공식 baseurl의 저장소/아키텍처 경로는 유지하고 미러와 버전 부분만 교체합니다.
    # mirrorlist만 있고 baseurl이 없는 공식 저장소는 추측하지 않고 중단합니다.
    awk -v base="$BASE_URL" '
        function flush(    i) {
            if (section == "kitten") { n=0; return }
            if (official_list && !converted) {
                print "공식 baseurl이 없는 저장소: " section > "/dev/stderr"
                failed=1
            }
            for (i=1; i<=n; i++) {
                if (converted && lines[i] ~ /^[[:space:]]*(mirrorlist|metalink)[[:space:]]*=/)
                    print "#" lines[i]
                else print lines[i]
            }
            n=0
        }
        /^[[:space:]]*\[/ {
            flush()
            section=$0
            sub(/^[[:space:]]*\[/, "", section)
            sub(/\].*$/, "", section)
            converted=0; official_list=0
        }
        {
            line=$0
            if (line ~ /^[[:space:]]*(mirrorlist|metalink)[[:space:]]*=/ &&
                line ~ /https?:\/\/([[:alnum:]-]+\.)*almalinux\.org\//)
                official_list=1
            if (line ~ /^[[:space:]]*#?[[:space:]]*baseurl[[:space:]]*=/) {
                url=line
                sub(/^[^=]*=[[:space:]]*/, "", url)
                if (url ~ /^https?:\/\/((repo|kitten\.repo)\.almalinux\.org|http\.krfoss\.org)\//) {
                    path=url
                    sub(/^https?:\/\/[^/]+\//, "", path)
                    sub(/^almalinux(-kitten)?\//, "", path)
                    if (path ~ /^(\$releasever|\$\{releasever\}|[0-9]+(\.[0-9]+)*)(-kitten)?\//) {
                        sub(/^[^/]+\//, "", path)
                        line="baseurl=" base "/" path
                        converted=1
                    }
                }
            }
            lines[++n]=line
        }
        END { flush(); if (failed) exit 1 }
    ' "$repo" > "$workdir/${repo##*/}.new"
done

# 모든 파일의 백업과 변환이 끝난 뒤 적용합니다.
applying=1
for repo in "${repos[@]}"; do
    cat "$workdir/${repo##*/}.new" > "$repo"
done
dnf clean all
dnf makecache
applying=0
echo "AlmaLinux Kitten ${VERSION_ID} 저장소가 ROKFOSS 분산미러로 변경되었습니다."
echo "기존 저장소 백업: $workdir"
