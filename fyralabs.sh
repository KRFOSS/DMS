#!/usr/bin/env bash

FYRA_DMS_URL="https://http.krfoss.org/fyralabs"

REPO_DIR="/etc/yum.repos.d"
NVIDIA_GPU=false
ULTRAMARINE_CHANGED=false
TERRA_REPOS=()
METADATA_GPG_FAILED=false

source /etc/os-release

if [[ "$EUID" -ne 0 ]]; then
  echo "root 권한이 필요합니다."
  exit 1
fi

if [[ "$ID" =~ ^(fedora|ultramarine|bazzite)$ ]]; then
  echo "감지된 배포판: $ID"

  if [[ "$ID" == "bazzite" ]]; then
    for command in rpm dnf5 rpm-ostree; do
      if ! command -v "$command" >/dev/null 2>&1; then
        echo "Bazzite에 필요한 명령을 찾을 수 없습니다: $command"
        exit 1
      fi
    done

    terra_repo_enabled() {
      local config
      config=$(dnf5 --dump-repo-config="$1") || return 1
      awk '
        /^[[:space:]]*enabled[[:space:]]*=/ {
          count++
          value=$0
          sub(/^[^=]*=[[:space:]]*/, "", value)
          sub(/[[:space:]]*$/, "", value)
        }
        END {
          if (count != 1 || value !~ /^(0|1)$/) exit 1
          print value
        }
      ' <<<"$config"
    }

    TERRA_DISABLED=false
    for suffix in "" -extras -mesa -multimedia -nvidia; do
      repo="terra$suffix"
      repo_file="$REPO_DIR/$repo.repo"
      if ! rpm -q "terra-release$suffix" >/dev/null 2>&1 ||
        [[ ! -f "$repo_file" ]]; then
        continue
      fi

      if ! enabled=$(terra_repo_enabled "$repo"); then
        echo "$repo 저장소 활성화 상태 확인에 실패했습니다."
        exit 1
      fi
      if [[ "$enabled" == "0" ]]; then
        TERRA_DISABLED=true
      fi
      TERRA_REPOS+=("$repo")
    done

    if [[ "${#TERRA_REPOS[@]}" -eq 0 ]]; then
      echo "변경할 Terra 저장소가 없습니다."
      exit 0
    fi

    activate=false
    if [[ "$TERRA_DISABLED" == "true" ]]; then
      printf -v repo_list '%s, ' "${TERRA_REPOS[@]}"
      repo_list=${repo_list%, }
      while true; do
        answer=""
        if ! read -r -p "Terra 저장소($repo_list)를 활성화하시겠습니까? [y/N] " answer; then
          echo
          break
        fi
        case "$answer" in
          y|Y|yes|YES) activate=true; break ;;
          n|N|no|NO|"") break ;;
          *) echo "y 또는 n을 입력하세요." ;;
        esac
      done
    fi

    for repo in "${TERRA_REPOS[@]}"; do
      repo_file="$REPO_DIR/$repo.repo"
      temp_file=$(mktemp) || exit 1
      if ! awk -v repo="$repo" -v mirror="$FYRA_DMS_URL" -v activate="$activate" '
        /^[[:space:]]*\[/ {
          section=$0
          sub(/^[[:space:]]*\[/, "", section)
          sub(/\].*$/, "", section)
          target=(section == repo || section == repo "-source")
          if (section == repo) found=1
          print
          if (section == repo && activate == "true") print "enabled=1"
          if (target) {
            suffix=section
            sub(/^terra/, "", suffix)
            print "baseurl=" mirror "/terra$releasever" suffix
          }
          next
        }
        target && /^[[:space:]]*(baseurl|metalink|mirrorlist)[[:space:]]*=/ { next }
        section == repo && activate == "true" && /^[[:space:]]*enabled[[:space:]]*=/ { next }
        { print }
        END { if (!found) exit 1 }
      ' "$repo_file" >"$temp_file" ||
        ! cp "$repo_file" "$repo_file.bak" ||
        ! cat "$temp_file" >"$repo_file"; then
        rm -f "$temp_file"
        echo "$repo 저장소 변경에 실패했습니다."
        exit 1
      fi
      rm -f "$temp_file"
      if [[ "$activate" == "true" ]]; then
        if ! dnf5 config-manager setopt --create-missing-dir "$repo.enabled=1"; then
          echo "$repo 저장소 활성화에 실패했습니다."
          exit 1
        fi
        if ! enabled=$(terra_repo_enabled "$repo") || [[ "$enabled" != "1" ]]; then
          echo "$repo 저장소 활성화 확인에 실패했습니다."
          exit 1
        fi
        echo "$repo 저장소가 활성화되었습니다."
      fi
      echo "$repo 저장소가 변경되었습니다."
    done

    TERRA_GPG_SUCCESS=true
    for repo in "${TERRA_REPOS[@]}"; do
      if ! dnf5 --refresh --repo="$repo" \
        --setopt="$repo.skip_if_unavailable=false" \
        --setopt="$repo.repo_gpgcheck=1" makecache -y >/dev/null 2>&1; then
        TERRA_GPG_SUCCESS=false
      fi
    done

    if [[ "$TERRA_GPG_SUCCESS" == "true" ]]; then
      printf 'Terra metadata GPG 검증: \033[92mSUCCESS\033[0m\n'
    else
      printf 'Terra metadata GPG 검증: \033[91mFAILED\033[0m\n'
      echo "Fyra Labs 저장소 metadata GPG 검증에 실패했습니다."
      exit 1
    fi

    echo "rpm-ostree 저장소 메타데이터 캐시를 삭제합니다."
    if ! rpm-ostree cleanup -m; then
      echo "rpm-ostree 저장소 메타데이터 캐시 삭제에 실패했습니다."
      exit 1
    fi

    echo "rpm-ostree 저장소 메타데이터를 갱신합니다."
    if ! rpm-ostree refresh-md --force; then
      echo "rpm-ostree 저장소 메타데이터 갱신에 실패했습니다."
      exit 1
    fi
    echo "Fyra Labs 저장소가 ROKFOSS 분산미러로 변경되었습니다."
    exit 0
  fi

  if command -v lspci >/dev/null 2>&1 &&
    lspci -nn 2>/dev/null | awk '
           { line=tolower($0) }
           line ~ /(vga|3d|display) controller/ && line ~ /nvidia/ { found=1 }
           END { exit !found }'; then
    NVIDIA_GPU=true
  fi

  echo "NVIDIA GPU 탐지: $NVIDIA_GPU"

  #
  # Ultramarine
  #

  if [[ "$ID" == "ultramarine" && -f "$REPO_DIR/ultramarine.repo" ]]; then
    cp \
      "$REPO_DIR/ultramarine.repo" \
      "$REPO_DIR/ultramarine.repo.bak"

    cat >"$REPO_DIR/ultramarine.repo" <<EOF
[ultramarine]
name=Ultramarine Linux \$releasever
baseurl=$FYRA_DMS_URL/um\$releasever
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-um\$releasever
repo_gpgcheck=1
enabled=1
enabled_metadata=1

[ultramarine-source]
name=Ultramarine Linux \$releasever - Source
baseurl=$FYRA_DMS_URL/um\$releasever-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-um\$releasever-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
EOF

    echo "Ultramarine 저장소가 변경되었습니다."
    ULTRAMARINE_CHANGED=true
  fi

  #
  # Terra
  #

  if rpm -q terra-release >/dev/null 2>&1 &&
    [[ -f "$REPO_DIR/terra.repo" ]]; then

    cp \
      "$REPO_DIR/terra.repo" \
      "$REPO_DIR/terra.repo.bak"

    cat >"$REPO_DIR/terra.repo" <<EOF
[terra]
name=Terra \$releasever
baseurl=$FYRA_DMS_URL/terra\$releasever
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever
repo_gpgcheck=1
enabled=1
enabled_metadata=1

[terra-source]
name=Terra \$releasever - Source
baseurl=$FYRA_DMS_URL/terra\$releasever-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
EOF

    echo "Terra 저장소가 변경되었습니다."
    TERRA_REPOS+=("terra")
  fi

  #
  # Terra Extras
  #

  if rpm -q terra-release-extras >/dev/null 2>&1 &&
    [[ -f "$REPO_DIR/terra-extras.repo" ]]; then

    cp \
      "$REPO_DIR/terra-extras.repo" \
      "$REPO_DIR/terra-extras.repo.bak"

    cat >"$REPO_DIR/terra-extras.repo" <<EOF
[terra-extras]
name=Terra \$releasever (Extras)
baseurl=$FYRA_DMS_URL/terra\$releasever-extras
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-extras
repo_gpgcheck=1
enabled=1
enabled_metadata=1
priority=150

[terra-extras-source]
name=Terra \$releasever (Extras) - Source
baseurl=$FYRA_DMS_URL/terra\$releasever-extras-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-extras-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
priority=150
EOF

    echo "Terra Extras 저장소가 변경되었습니다."
    TERRA_REPOS+=("terra-extras")
  fi

  #
  # Terra Mesa
  #

  if rpm -q terra-release-mesa >/dev/null 2>&1 &&
    [[ -f "$REPO_DIR/terra-mesa.repo" ]]; then

    cp \
      "$REPO_DIR/terra-mesa.repo" \
      "$REPO_DIR/terra-mesa.repo.bak"

    cat >"$REPO_DIR/terra-mesa.repo" <<EOF
[terra-mesa]
name=Terra \$releasever (Mesa)
baseurl=$FYRA_DMS_URL/terra\$releasever-mesa
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-mesa
repo_gpgcheck=1
enabled=1
enabled_metadata=1
priority=80

[terra-mesa-source]
name=Terra \$releasever (Mesa) - Source
baseurl=$FYRA_DMS_URL/terra\$releasever-mesa-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-mesa-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
priority=80
EOF

    echo "Terra Mesa 저장소가 변경되었습니다."
    TERRA_REPOS+=("terra-mesa")
  fi

  #
  # Terra Multimedia
  #

  if rpm -q terra-release-multimedia >/dev/null 2>&1 &&
    [[ -f "$REPO_DIR/terra-multimedia.repo" ]]; then

    cp \
      "$REPO_DIR/terra-multimedia.repo" \
      "$REPO_DIR/terra-multimedia.repo.bak"

    cat >"$REPO_DIR/terra-multimedia.repo" <<EOF
[terra-multimedia]
name=Terra \$releasever (Multimedia)
baseurl=$FYRA_DMS_URL/terra\$releasever-multimedia
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-multimedia
repo_gpgcheck=1
enabled=1
enabled_metadata=1
priority=80

[terra-multimedia-source]
name=Terra \$releasever (Multimedia) - Source
baseurl=$FYRA_DMS_URL/terra\$releasever-multimedia-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-multimedia-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
priority=80
EOF

    echo "Terra Multimedia 저장소가 변경되었습니다."
    TERRA_REPOS+=("terra-multimedia")
  fi

  #
  # Terra NVIDIA
  #

  if [[ "$NVIDIA_GPU" == "true" ]]; then
    if rpm -q terra-release-nvidia >/dev/null 2>&1 &&
      [[ -f "$REPO_DIR/terra-nvidia.repo" ]]; then

      echo "Terra Release NVIDIA 패키지가 설치되어 있습니다. 해당 저장소를 포함하여 변경합니다."

      cp \
        "$REPO_DIR/terra-nvidia.repo" \
        "$REPO_DIR/terra-nvidia.repo.bak"

      cat >"$REPO_DIR/terra-nvidia.repo" <<EOF
[terra-nvidia]
name=Terra \$releasever (NVIDIA)
baseurl=$FYRA_DMS_URL/terra\$releasever-nvidia
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-nvidia
repo_gpgcheck=1
enabled=1
enabled_metadata=1
priority=80

[terra-nvidia-source]
name=Terra \$releasever (NVIDIA) - Source
baseurl=$FYRA_DMS_URL/terra\$releasever-nvidia-source
metadata_expire=6h
type=rpm
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-terra\$releasever-nvidia-source
repo_gpgcheck=1
enabled=0
enabled_metadata=0
priority=80
EOF

      echo "Terra NVIDIA 저장소가 변경되었습니다."
      TERRA_REPOS+=("terra-nvidia")
    fi
  fi

  sleep 2

  if [[ "$ULTRAMARINE_CHANGED" == "true" ]]; then
    if dnf makecache --disablerepo='*' --enablerepo='ultramarine' >/dev/null 2>&1; then
      printf 'Ultramarine metadata GPG 검증: \033[92mSUCCESS\033[0m\n'
    else
      printf 'Ultramarine metadata GPG 검증: \033[91mFAILED\033[0m\n'
      METADATA_GPG_FAILED=true
    fi
  fi

  if [[ "${#TERRA_REPOS[@]}" -gt 0 ]]; then
    TERRA_GPG_SUCCESS=true

    for repo in "${TERRA_REPOS[@]}"; do
      if ! dnf makecache --disablerepo='*' --enablerepo="$repo" >/dev/null 2>&1; then
        TERRA_GPG_SUCCESS=false
      fi
    done

    if [[ "$TERRA_GPG_SUCCESS" == "true" ]]; then
      printf 'Terra metadata GPG 검증: \033[92mSUCCESS\033[0m\n'
    else
      printf 'Terra metadata GPG 검증: \033[91mFAILED\033[0m\n'
      METADATA_GPG_FAILED=true
    fi
  fi

  echo "DNF 캐시 삭제 및 업데이트를 진행합니다."

  if dnf clean all && dnf makecache -y; then
    if [[ "$METADATA_GPG_FAILED" == "true" ]]; then
      echo "Fyra Labs 저장소 metadata GPG 검증에 실패했습니다."
      exit 1
    fi

    echo "Fyra Labs 저장소가 ROKFOSS 분산미러로 변경되었습니다."
  else
    echo "DNF 캐시 삭제 또는 업데이트에 실패했습니다."
    exit 1
  fi

else
  echo "올바르지 않은 배포판입니다. 이 스크립트는 Fedora, Ultramarine 또는 Bazzite에서만 사용할 수 있습니다."
  exit 1
fi
