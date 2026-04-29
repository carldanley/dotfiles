#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install-prerequisites.sh [--dry-run] [--import-gpg] [--gpg-vault VAULT] [--gpg-item ITEM]

Installs the minimum prerequisites needed before running the full dotfiles
apply on a fresh machine:
  - Xcode Command Line Tools (macOS only)
  - Homebrew
  - chezmoi
  - 1Password app and CLI
  - gnupg
  - pinentry-mac (macOS only)

Optional:
  --import-gpg   Import GPG key material from 1Password after prerequisites install
  --gpg-vault    1Password vault name that contains your GPG key bundle
  --gpg-item     1Password item title or ID for your GPG key bundle
EOF
}

log_info() {
  printf '==> %s\n' "$*"
}

log_warn() {
  printf 'WARN: %s\n' "$*" >&2
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_non_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    error "Do not run this installer as root. Run it as your normal user; Homebrew will request elevation itself when needed."
  fi
}

dry_run=0
import_gpg=0
gpg_import_result="skipped"
gpg_import_signing_key=""
gpg_import_fingerprint=""
gpg_bundle_vault="${DOTFILES_GPG_BUNDLE_VAULT-}"
gpg_bundle_item="${DOTFILES_GPG_BUNDLE_ITEM-}"
gpg_bundle_public_name="Public"
gpg_bundle_secret_subkeys_name="SecretSubKeys"
gpg_bundle_ownertrust_name="Ownertrust"
gpg_bundle_revocation_name="Revocation"

while (($# > 0)); do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --import-gpg)
      import_gpg=1
      shift
      ;;
    --gpg-vault)
      [[ $# -ge 2 ]] || error "Missing value for --gpg-vault"
      gpg_bundle_vault="$2"
      shift 2
      ;;
    --gpg-item)
      [[ $# -ge 2 ]] || error "Missing value for --gpg-item"
      gpg_bundle_item="$2"
      shift 2
      ;;
    *)
      error "Unsupported argument: $1"
      ;;
  esac
done

require_non_root

is_darwin() {
  [[ "$(uname -s)" == "Darwin" ]]
}

has_1password_app() {
  [[ -d /Applications/1Password.app || -d "$HOME/Applications/1Password.app" ]]
}

prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local current_value="${!var_name-}"

  if [[ -n "$current_value" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    error "${prompt_text}. Pass it with a flag or set an environment variable first."
  fi

  printf '%s: ' "$prompt_text" >&2
  IFS= read -r current_value
  if [[ -z "$current_value" ]]; then
    error "${prompt_text} is required."
  fi

  printf -v "$var_name" '%s' "$current_value"
}

brew_shellenv_eval_command() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    printf '%s\n' 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    return 0
  fi

  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    printf '%s\n' 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    return 0
  fi

  return 1
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

ensure_xcode_command_line_tools() {
  if ! is_darwin; then
    return 0
  fi

  if xcode-select -p >/dev/null 2>&1; then
    log_info "Xcode Command Line Tools already installed"
    return 0
  fi

  if ((dry_run)); then
    log_info "Would trigger Xcode Command Line Tools installation"
    return 0
  fi

  log_info "Starting Xcode Command Line Tools installation"
  xcode-select --install || true
  error "Finish installing Xcode Command Line Tools, then rerun './install.sh --prereqs'."
}

ensure_homebrew() {
  if eval_brew_shellenv; then
    log_info "Homebrew already installed"
    return 0
  fi

  log_info "Installing Homebrew"

  if ((dry_run)); then
    printf '%s\n' '+ NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    return 0
  fi

  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval_brew_shellenv || error "Homebrew installed, but brew shellenv could not be loaded."
}

install_brew_prerequisites() {
  local bundle

  bundle=$(
    cat <<'EOF'
brew "chezmoi"
brew "gnupg"
cask "1password-cli"
EOF
  )

  if is_darwin; then
    bundle="${bundle}
brew \"pinentry-mac\""

    if has_1password_app; then
      log_info "1Password app already present; skipping Homebrew cask install"
    else
      bundle="${bundle}
cask \"1password\""
    fi
  fi

  log_info "Installing prerequisite Homebrew packages"

  if ((dry_run)); then
    printf '%s\n' "$bundle"
    return 0
  fi

  printf '%s\n' "$bundle" | brew bundle --file=/dev/stdin
}

check_onepassword_status() {
  if ! command -v op >/dev/null 2>&1; then
    log_warn "1Password CLI is not available yet."
    return 0
  fi

  if op account list >/dev/null 2>&1; then
    log_info "1Password CLI is installed and can see at least one configured account"
  else
    log_warn "1Password CLI is installed, but no account is configured yet."
  fi
}

check_gpg_status() {
  if ! command -v gpg >/dev/null 2>&1; then
    log_warn "gpg is not available yet."
    return 0
  fi

  if gpg --list-secret-keys --with-colons | grep -q '^sec:'; then
    log_info "At least one GPG secret key is already available"
  else
    log_warn "No GPG secret keys found yet. Import or create one before enabling signed Git commits."
  fi
}

ensure_gpg_pinentry() {
  local gnupg_dir gpg_agent_conf pinentry_path

  if ! is_darwin; then
    return 0
  fi

  if ! command -v gpgconf >/dev/null 2>&1; then
    return 0
  fi

  pinentry_path="$(command -v pinentry-mac || true)"
  if [[ -z "$pinentry_path" ]]; then
    log_warn "pinentry-mac is not available yet."
    return 0
  fi

  gnupg_dir="${HOME}/.gnupg"
  gpg_agent_conf="${gnupg_dir}/gpg-agent.conf"

  mkdir -p "$gnupg_dir"
  chmod 700 "$gnupg_dir"
  touch "$gpg_agent_conf"
  chmod 600 "$gpg_agent_conf"

  if grep -q '^pinentry-program ' "$gpg_agent_conf"; then
    if grep -q "^pinentry-program ${pinentry_path}\$" "$gpg_agent_conf"; then
      return 0
    fi

    log_warn "gpg-agent.conf already sets a custom pinentry-program; leaving it unchanged."
  else
    printf 'pinentry-program %s\n' "$pinentry_path" >> "$gpg_agent_conf"
    log_info "Configured gpg-agent to use pinentry-mac"
  fi

  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true
}

ensure_gpg_bundle_location() {
  if (( ! import_gpg )) || (( dry_run )); then
    return 0
  fi

  prompt_if_empty gpg_bundle_vault "Enter the 1Password vault name containing your GPG bundle"
  prompt_if_empty gpg_bundle_item "Enter the 1Password item title or ID for your GPG bundle"
}

ensure_op_read_access() {
  if ! command -v op >/dev/null 2>&1; then
    error "1Password CLI is required for --import-gpg."
  fi

  if ! OP_BIOMETRIC_UNLOCK_ENABLED=true op vault get "$gpg_bundle_vault" >/dev/null 2>&1; then
    error "Unable to access 1Password vault '${gpg_bundle_vault}'. Make sure the desktop app is unlocked and CLI integration is enabled."
  fi
}

download_gpg_bundle_file() {
  local item_id="$1"
  local file_id="$2"
  local out_file="$3"

  : > "$out_file"
  OP_BIOMETRIC_UNLOCK_ENABLED=true op read "op://${gpg_bundle_vault}/${item_id}/${file_id}?attr=content" > "$out_file"
}

extract_first_signing_key_from_import() {
  local import_file="$1"
  gpg --import-options show-only --import --with-colons "$import_file" | awk -F: '/^sec:/ { print $5; exit }'
}

extract_first_fingerprint_from_import() {
  local import_file="$1"
  gpg --import-options show-only --import --with-colons "$import_file" | awk -F: '/^fpr:/ { print $10; exit }'
}

extract_item_field_value() {
  local item_json="$1"
  local field_label="$2"
  jq -r --arg label "$field_label" '[.fields[]? | select(.label == $label) | .value][0] // empty' <<<"$item_json"
}

has_local_secret_key() {
  local key_spec="$1"

  if [[ -z "$key_spec" ]]; then
    return 1
  fi

  gpg --batch --with-colons --list-secret-keys "$key_spec" 2>/dev/null | grep -Eq '^(sec|ssb):'
}

persist_chezmoi_signing_key() {
  local config_dir config_file

  if [[ -z "$gpg_import_signing_key" ]]; then
    return 0
  fi

  config_dir="${HOME}/.config/chezmoi"
  config_file="${config_dir}/chezmoi.yaml"

  mkdir -p "$config_dir"
  chmod 700 "$config_dir"

  if [[ -e "$config_file" ]]; then
    log_warn "chezmoi config already exists at ${config_file}; leaving it unchanged. Ensure data.git.signingkey is set to '${gpg_import_signing_key}'."
    return 0
  fi

  cat > "$config_file" <<EOF
data:
  git:
    signingkey: "${gpg_import_signing_key}"
EOF
  chmod 600 "$config_file"
  log_info "Wrote local chezmoi config with imported git signing key"
}

import_gpg_from_1password() {
  local item_json item_id temp_dir public_file secret_subkeys_file ownertrust_file revocation_file
  local detected_signing_key detected_fingerprint

  if (( ! import_gpg )); then
    return 0
  fi

  if (( dry_run )); then
    gpg_import_result="dry-run"
    return 0
  fi

  ensure_gpg_bundle_location
  ensure_op_read_access
  ensure_gpg_pinentry

  if [[ -t 0 ]] || [[ -t 1 ]]; then
    export GPG_TTY
    GPG_TTY="$(tty 2>/dev/null || true)"
  fi

  item_json="$(OP_BIOMETRIC_UNLOCK_ENABLED=true op item get "$gpg_bundle_item" --vault "$gpg_bundle_vault" --format json)"
  item_id="$(jq -r '.id' <<<"$item_json")"
  if [[ -z "$item_id" || "$item_id" == "null" ]]; then
    error "Could not find 1Password item '${gpg_bundle_item}' in vault '${gpg_bundle_vault}'."
  fi

  temp_dir="$(mktemp -d)"
  chmod 700 "$temp_dir"
  trap 'rm -rf "$temp_dir"' RETURN

  public_file="${temp_dir}/gpg-public.asc"
  secret_subkeys_file="${temp_dir}/gpg-secret-subkeys.asc"
  ownertrust_file="${temp_dir}/gpg-ownertrust.txt"
  revocation_file="${temp_dir}/gpg-revocation-cert.rev"

  log_info "Downloading GPG key bundle from 1Password item '${gpg_bundle_item}'"
  download_gpg_bundle_file "$item_id" "$gpg_bundle_public_name" "$public_file"
  download_gpg_bundle_file "$item_id" "$gpg_bundle_secret_subkeys_name" "$secret_subkeys_file"
  download_gpg_bundle_file "$item_id" "$gpg_bundle_ownertrust_name" "$ownertrust_file"
  download_gpg_bundle_file "$item_id" "$gpg_bundle_revocation_name" "$revocation_file"

  detected_signing_key="$(extract_item_field_value "$item_json" "SigningKey")"
  detected_fingerprint="$(extract_item_field_value "$item_json" "Fingerprint")"

  if [[ -z "$detected_signing_key" ]]; then
    detected_signing_key="$(extract_first_signing_key_from_import "$secret_subkeys_file")"
  fi
  if [[ -z "$detected_fingerprint" ]]; then
    detected_fingerprint="$(extract_first_fingerprint_from_import "$secret_subkeys_file")"
  fi

  log_info "Importing public key"
  gpg --import "$public_file"

  log_info "Importing secret subkeys"
  gpg --import "$secret_subkeys_file"

  log_info "Importing ownertrust"
  gpg --import-ownertrust "$ownertrust_file"

  mkdir -p "${HOME}/.local/share/dotfiles-backups"
  install -m 600 "$revocation_file" "${HOME}/.local/share/dotfiles-backups/gpg-revocation-cert.rev"

  gpg_import_signing_key="$detected_signing_key"
  gpg_import_fingerprint="$detected_fingerprint"

  if has_local_secret_key "$gpg_import_signing_key"; then
    gpg_import_result="imported"
    persist_chezmoi_signing_key
  else
    gpg_import_result="imported-no-signing-key"
  fi

  log_info "Saved revocation certificate backup to ~/.local/share/dotfiles-backups/gpg-revocation-cert.rev"

  rm -rf "$temp_dir"
  trap - RETURN
}

print_next_steps() {
  shellenv_hint="$(brew_shellenv_eval_command || true)"

  cat <<'EOF'

Next steps:
EOF

  if [[ -n "${shellenv_hint}" ]]; then
    printf '  1. If `brew` or `op` is not found in this shell, run `%s` or open a new terminal.\n' "${shellenv_hint}"
  else
    printf '%s\n' '  1. If `brew` or `op` is not found in this shell, open a new terminal first.'
  fi

  cat <<'EOF'
  2. Open and unlock the 1Password app, then go to Settings > Developer and turn on "Integrate with 1Password CLI".
  3. Run `op signin` to choose an account, or run `op vault list` and let 1Password prompt you.
EOF

  if [[ "$gpg_import_result" == "imported" ]]; then
    printf '  4. GPG key material was imported from 1Password.\n'
    if [[ -n "$gpg_import_signing_key" ]]; then
      printf '     Use this signing key when prompted: `%s`\n' "$gpg_import_signing_key"
    fi
    if [[ -n "$gpg_import_fingerprint" ]]; then
      printf '     Fingerprint: `%s`\n' "$gpg_import_fingerprint"
    fi
    printf '%s\n' '  5. Run `./install.sh` for the full chezmoi apply.'
  elif [[ "$gpg_import_result" == "imported-no-signing-key" ]]; then
    printf '%s\n' '  4. The GPG bundle was imported, but no usable local secret signing key was found for the configured signing key.'
    if [[ -n "$gpg_import_signing_key" ]]; then
      printf '     Configured signing key: `%s`\n' "$gpg_import_signing_key"
    fi
    printf '%s\n' '     This usually means the bundle contains secret subkeys but your signing capability lives on the primary key.'
    printf '%s\n' '     Export the full secret key instead, or create a dedicated signing subkey and update the 1Password bundle.'
    printf '%s\n' '  5. After updating the bundle, re-run `./install.sh --prereqs --import-gpg`.'
  elif [[ "$gpg_import_result" == "dry-run" ]]; then
    printf '%s\n' '  4. Re-run with `--import-gpg` if you want to import your GPG bundle from 1Password.'
    printf '%s\n' '  5. Run `./install.sh` for the full chezmoi apply.'
  else
    printf '%s\n' '  4. Import or create your GPG signing key. Re-run with `--import-gpg` to import it from 1Password.'
    printf '%s\n' '  5. Run `./install.sh` for the full chezmoi apply.'
  fi
}

ensure_xcode_command_line_tools
ensure_homebrew
install_brew_prerequisites
import_gpg_from_1password

if ((dry_run)); then
  print_next_steps
  exit 0
fi

eval_brew_shellenv || true
check_onepassword_status
check_gpg_status
print_next_steps
