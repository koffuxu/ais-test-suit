#!/usr/bin/env bash
set -euo pipefail

# FTP 上传脚本（支持文件与文件夹），优先使用 lftp
# 适用平台：Ubuntu / macOS

HOST="ftp-hpc.aispeech.com.cn"
PORT=2121
USER="gangfeng.xu"
DEFAULT_REMOTE_BASE="/midea-2025"

usage(){
  cat <<'EOF'
Usage: $(basename "$0") <local_path> <remote_folder>

Upload a local file or directory to FTP server under the default base folder.

Arguments:
  local_path     Local file or directory to upload
  remote_folder  Name of folder to create/use under default remote base

Options:
  -h, --help     Show this help message

Environment:
  FTP_PASSWORD   If set, will be used as the FTP password. Otherwise you will be prompted.
  FTP_SKIP_CERT_VERIFY  If set to 1, skip TLS certificate verification (unsafe).

Examples:
  $(basename "$0") ./mydir project-uploads
  $(basename "$0") ./file.txt backups/nov

Requirements:
  This script uses `lftp`. Install it with:
    - Ubuntu: sudo apt update && sudo apt install -y lftp
    - macOS:  brew install lftp

EOF
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ $# -ne 2 ]; then
  echo "Error: expected 2 arguments."
  usage
  exit 1
fi

LOCAL_PATH="$1"
REMOTE_SUBDIR="$2"

if [ ! -e "$LOCAL_PATH" ]; then
  echo "Error: local path '$LOCAL_PATH' does not exist." >&2
  exit 2
fi

# Get password from env or prompt
FTP_PASSWORD_PROMPTED=""
if [ -z "${FTP_PASSWORD:-}" ]; then
  # Prompt securely
  printf "Enter FTP password for %s@%s: " "$USER" "$HOST"
  stty -echo
  read -r FTP_PASSWORD_PROMPTED || true
  stty echo
  echo
  PASS="$FTP_PASSWORD_PROMPTED"
else
  PASS="$FTP_PASSWORD"
fi

# Optional: allow skipping certificate verification for servers using self-signed certs
# Set environment variable `FTP_SKIP_CERT_VERIFY=1` to disable certificate checks (unsafe)
FTP_SKIP_CERT_VERIFY="${FTP_SKIP_CERT_VERIFY:-0}"
if [ "$FTP_SKIP_CERT_VERIFY" = "1" ]; then
  LFTP_CERT_SETTING="set ssl:verify-certificate no"
else
  LFTP_CERT_SETTING=""
fi

if ! command -v lftp >/dev/null 2>&1; then
  echo "Error: required tool 'lftp' not found." >&2
  echo "Install it: Ubuntu: sudo apt install lftp  |  macOS: brew install lftp" >&2
  exit 3
fi

# Normalize remote base (remove trailing slash)
REMOTE_BASE="${DEFAULT_REMOTE_BASE%/}"

# Full remote target folder (absolute)
REMOTE_TARGET="$REMOTE_BASE/$REMOTE_SUBDIR"

is_dir=false
if [ -d "$LOCAL_PATH" ]; then
  is_dir=true
fi

echo "Uploading '$LOCAL_PATH' -> ftp://$HOST:$PORT$REMOTE_TARGET"

if $is_dir; then
  # For directories, use lcd to parent and mirror the directory basename
  LOCAL_PARENT=$(dirname "$LOCAL_PATH")
  LOCAL_BASENAME=$(basename "$LOCAL_PATH")

  lftp -u "$USER","$PASS" -p "$PORT" "$HOST" <<EOF
${LFTP_CERT_SETTING}
set ftp:ssl-allow yes
set ftp:ssl-force true
set ftp:ssl-protect-data true
set net:max-retr-fail 2
mkdir -p "$REMOTE_TARGET"
lcd "$LOCAL_PARENT"
mirror -R --parallel=2 --verbose "$LOCAL_BASENAME" "$REMOTE_TARGET"
bye
EOF
else
  # Single file: lcd to parent, ensure remote dir exists, cd and put
  LOCAL_PARENT=$(dirname "$LOCAL_PATH")
  LOCAL_BASENAME=$(basename "$LOCAL_PATH")

  lftp -u "$USER","$PASS" -p "$PORT" "$HOST" <<EOF
${LFTP_CERT_SETTING}
set ftp:ssl-allow yes
set ftp:ssl-force true
set ftp:ssl-protect-data true
mkdir -p "$REMOTE_TARGET"
lcd "$LOCAL_PARENT"
cd "$REMOTE_TARGET"
put -E "$LOCAL_BASENAME"
bye
EOF
fi

echo "Upload finished."
