#!/usr/bin/env bash
set -euo pipefail
shopt -s inherit_errexit nullglob

# ===== sudo wrapper =====
SUDO=""
[[ $EUID -eq 0 ]] || SUDO="sudo"

# ===== Colors & Symbols =====
RD="\033[01;31m"
YW="\033[33m"
GN="\033[1;92m"
CL="\033[m"
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

# ===== Message Functions =====
msg_info()  { echo -ne " ${HOLD} ${YW}$1..."; }
msg_ok()    { echo -e "${BFR} ${CM} ${GN}$1${CL}"; }
msg_error() { echo -e "${BFR} ${CROSS} ${RD}$1${CL}"; }

# ===== Confirmation Prompt =====
confirm() {
    read -rp "⚠️  $1? [y/N]: " ans
    [[ $ans =~ ^[Yy] ]] || return 1
}

# ===== Header =====
header_info() {
    clear
    cat <<"EOF"
    ____ _    ________   ____             __     ____           __        ____
   / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __ `/ / /
 / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/
EOF
}
