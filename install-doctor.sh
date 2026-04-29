#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install-doctor.sh
  ./install-doctor.sh --gpg-expiry-warning-days DAYS

Checks whether this machine is ready for the dotfiles bootstrap and full
chezmoi apply. The command exits non-zero if any required checks fail.
EOF
}

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
repo_root="$script_dir"

require_non_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    printf 'FAIL Do not run doctor as root.\n' >&2
    exit 1
  fi
}

is_darwin() {
  [[ "$(uname -s)" == "Darwin" ]]
}

eval_brew_shellenv() {
  if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    return 0
  fi

  return 1
}

format_epoch_date() {
  local epoch="$1"

  if date -r "$epoch" '+%Y-%m-%d' >/dev/null 2>&1; then
    date -r "$epoch" '+%Y-%m-%d'
  else
    date -d "@$epoch" '+%Y-%m-%d'
  fi
}

ok() {
  printf 'OK   %s\n' "$1"
  ok_count=$((ok_count + 1))
}

warn() {
  printf 'WARN %s\n' "$1"
  warn_count=$((warn_count + 1))
}

fail() {
  printf 'FAIL %s\n' "$1"
  fail_count=$((fail_count + 1))
}

check_xcode_command_line_tools() {
  if ! is_darwin; then
    return 0
  fi

  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode Command Line Tools are installed"
  else
    fail "Xcode Command Line Tools are missing"
  fi
}

check_homebrew() {
  if eval_brew_shellenv; then
    ok "Homebrew is installed"
  else
    fail "Homebrew is missing"
  fi
}

check_chezmoi() {
  if command -v chezmoi >/dev/null 2>&1; then
    ok "chezmoi is installed"
  else
    fail "chezmoi is missing"
  fi
}

check_1password() {
  if ! command -v op >/dev/null 2>&1; then
    fail "1Password CLI is missing"
    return 0
  fi

  ok "1Password CLI is installed"

  if is_darwin; then
    if [[ -d /Applications/1Password.app || -d "$HOME/Applications/1Password.app" ]]; then
      ok "1Password app is installed"
    else
      warn "1Password app is not installed"
    fi
  fi

  if op account list >/dev/null 2>&1; then
    ok "1Password CLI can see configured accounts"
  else
    warn "1Password CLI cannot see any configured accounts"
  fi

  if OP_BIOMETRIC_UNLOCK_ENABLED=true op vault list >/dev/null 2>&1; then
    ok "1Password CLI can access vault data"
  else
    fail "1Password CLI cannot access vault data. Unlock the app and enable Settings > Developer > Integrate with 1Password CLI"
  fi
}

check_gpg_tools() {
  if command -v gpg >/dev/null 2>&1; then
    ok "gpg is installed"
  else
    fail "gpg is missing"
    return 0
  fi

  if command -v gpgconf >/dev/null 2>&1; then
    ok "gpgconf is installed"
  else
    fail "gpgconf is missing"
  fi

  if ! is_darwin; then
    return 0
  fi

  if command -v pinentry-mac >/dev/null 2>&1; then
    ok "pinentry-mac is installed"
  else
    warn "pinentry-mac is missing"
  fi

  local gpg_agent_conf pinentry_path
  gpg_agent_conf="${HOME}/.gnupg/gpg-agent.conf"
  pinentry_path="$(command -v pinentry-mac || true)"

  if [[ -n "$pinentry_path" && -f "$gpg_agent_conf" ]] && grep -q "^pinentry-program ${pinentry_path}\$" "$gpg_agent_conf"; then
    ok "gpg-agent is configured to use pinentry-mac"
  elif [[ -f "$gpg_agent_conf" ]] && grep -q '^pinentry-program ' "$gpg_agent_conf"; then
    warn "gpg-agent.conf points to a custom pinentry-program"
  else
    warn "gpg-agent is not configured to use pinentry-mac yet"
  fi
}

check_gpg_keyring() {
  local secret_dump
  secret_dump="$(gpg --batch --with-colons --list-secret-keys 2>/dev/null || true)"

  if grep -Eq '^(sec|ssb):' <<<"$secret_dump"; then
    ok "At least one secret GPG key is available locally"
  else
    warn "No local secret GPG keys were found"
  fi
}

desired_go_version() {
  awk '
    /^  go:$/ { in_go=1; next }
    in_go && /^    version:/ {
      gsub(/"/, "", $2)
      print $2
      exit
    }
    in_go && /^[^ ]/ { in_go=0 }
  ' "$repo_root/home/.chezmoi.yaml.tmpl"
}

check_goenv() {
  local go_version_name expected_go_version go_output

  if ! command -v goenv >/dev/null 2>&1; then
    warn "goenv is not installed"
    return 0
  fi

  ok "goenv is installed"

  export GOENV_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/.goenv"
  export PATH="$GOENV_ROOT/bin:$PATH"
  eval "$(goenv init -)"

  expected_go_version="$(desired_go_version)"
  go_version_name="$(goenv version-name 2>/dev/null || true)"

  if [[ -z "$expected_go_version" ]]; then
    warn "Could not determine the desired Go version from the repo"
    return 0
  fi

  if [[ "$go_version_name" == "$expected_go_version" ]]; then
    ok "goenv global version is ${go_version_name}"
  elif [[ "$go_version_name" == "system" ]]; then
    warn "goenv is still set to system instead of ${expected_go_version}"
  else
    warn "goenv version is ${go_version_name}, expected ${expected_go_version}"
  fi

  if ! command -v go >/dev/null 2>&1; then
    warn "go is not currently available on PATH through goenv"
    return 0
  fi

  go_output="$(go version 2>/dev/null || true)"
  if [[ "$go_output" == *"go${expected_go_version}"* ]]; then
    ok "Go runtime matches the repo target version ${expected_go_version}"
  else
    warn "Go runtime does not match the repo target version ${expected_go_version}: ${go_output}"
  fi
}

check_chezmoi_signing_key() {
  local config_file configured_key key_dump key_line key_id expires caps expiry_date warn_epoch now

  config_file="${HOME}/.config/chezmoi/chezmoi.yaml"
  if [[ ! -f "$config_file" ]]; then
    warn "Local chezmoi config is missing; full install may prompt for git.signingkey"
    return 0
  fi

  configured_key="$(awk '/signingkey:/ {print $2; exit}' "$config_file" | tr -d '"')"
  if [[ -z "$configured_key" ]]; then
    warn "Local chezmoi config exists, but no git.signingkey was found"
    return 0
  fi

  ok "Local chezmoi git.signingkey is set to ${configured_key}"

  key_dump="$(gpg --batch --with-colons --list-secret-keys "$configured_key" 2>/dev/null || true)"
  key_line="$(grep -E '^(sec|ssb):' <<<"$key_dump" | head -n 1 || true)"

  if [[ -z "$key_line" ]]; then
    fail "Configured signing key ${configured_key} is not available in the local secret keyring"
    return 0
  fi

  IFS=':' read -r _ _ _ _ key_id _ expires _ _ _ _ caps _ <<<"$key_line"

  if [[ "$caps" == *S* || "$caps" == *s* ]]; then
    ok "Configured signing key ${key_id} has signing capability"
  else
    fail "Configured signing key ${key_id} does not have signing capability"
  fi

  if [[ -z "$expires" ]]; then
    ok "Configured signing key ${key_id} does not expire"
    return 0
  fi

  now="$(date +%s)"
  warn_epoch=$((now + gpg_expiry_warning_days * 86400))
  expiry_date="$(format_epoch_date "$expires")"

  if (( expires <= now )); then
    fail "Configured signing key ${key_id} expired on ${expiry_date}"
  elif (( expires <= warn_epoch )); then
    warn "Configured signing key ${key_id} expires soon on ${expiry_date}"
  else
    ok "Configured signing key ${key_id} is valid until ${expiry_date}"
  fi
}

print_summary() {
  printf '\nSummary: %s ok, %s warnings, %s failures\n' "$ok_count" "$warn_count" "$fail_count"

  if (( fail_count > 0 )); then
    printf 'Doctor found blocking issues.\n'
    exit 1
  fi

  if (( warn_count > 0 )); then
    printf 'Doctor found non-blocking issues worth reviewing.\n'
    exit 0
  fi

  printf 'Doctor found no issues.\n'
}

ok_count=0
warn_count=0
fail_count=0
gpg_expiry_warning_days=30

while (($# > 0)); do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --gpg-expiry-warning-days)
      [[ $# -ge 2 ]] || { printf 'Missing value for --gpg-expiry-warning-days\n' >&2; exit 1; }
      gpg_expiry_warning_days="$2"
      shift 2
      ;;
    *)
      printf 'Unsupported argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_non_root
check_xcode_command_line_tools
check_homebrew
check_chezmoi
check_1password
check_gpg_tools
check_gpg_keyring
check_chezmoi_signing_key
check_goenv
print_summary
