#!/bin/sh

# -e: exit on error
# -u: exit on unset variables
set -eu

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [chezmoi args...]
  ./install.sh --prereqs [prereq args...]
  ./install.sh --doctor [doctor args...]

Modes:
  default        Install and run chezmoi against this repository
  --prereqs      Install the minimum prerequisites needed on a fresh machine
                  Pass through args like --dry-run or --import-gpg
  --doctor       Run local readiness checks before a full apply
EOF
}

log_color() {
  color_code="$1"
  shift

  printf "\033[${color_code}m%s\033[0m\n" "$*" >&2
}

log_red() {
  log_color "0;31" "$@"
}

log_blue() {
  log_color "0;34" "$@"
}

log_task() {
  log_blue "🔃" "$@"
}

log_error() {
  log_red "❌" "$@"
}

error() {
  log_error "$@"
  exit 1
}

require_non_root() {
  if [ "$(id -u)" -eq 0 ]; then
    error "Do not run this installer as root. Run it as your normal user; commands that need elevation will prompt for sudo."
  fi
}

mode="apply"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --mode)
      [ "$#" -ge 2 ] || error "Missing value for --mode"
      mode="$2"
      shift 2
      ;;
    --prereqs|prereqs|prerequisites)
      mode="prereqs"
      shift
      ;;
    --doctor|doctor)
      mode="doctor"
      shift
      ;;
    --apply|apply)
      mode="apply"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

case "$mode" in
  apply|prereqs|doctor)
    ;;
  *)
    error "Unsupported install mode: ${mode}"
    ;;
esac

require_non_root

if [ "$mode" = "prereqs" ]; then
  script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
  exec "${script_dir}/install-prerequisites.sh" "$@"
fi

if [ "$mode" = "doctor" ]; then
  script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
  exec bash "${script_dir}/install-doctor.sh" "$@"
fi

if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
  chezmoi="${bin_dir}/chezmoi"
  log_task "Installing chezmoi to '${chezmoi}'"
  if command -v curl >/dev/null; then
    chezmoi_install_script="$(curl -fsSL https://get.chezmoi.io)"
  elif command -v wget >/dev/null; then
    chezmoi_install_script="$(wget -qO- https://get.chezmoi.io)"
  else
    error "To install chezmoi, you must have curl or wget."
  fi
  sh -c "${chezmoi_install_script}" -- -b "${bin_dir}"
  unset chezmoi_install_script bin_dir
fi

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

set -- init --source="${script_dir}" --verbose=false "$@"

if [ -n "${DOTFILES_ONE_SHOT-}" ]; then
  set -- "$@" --one-shot
else
  set -- "$@" --apply
fi

if [ -n "${DOTFILES_DEBUG-}" ]; then
  set -- "$@" --debug
fi

# eval brew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

log_task "Running 'chezmoi $*'"
exec "${chezmoi}" "$@"
