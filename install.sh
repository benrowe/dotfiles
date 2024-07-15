#!/usr/bin/env bash

echo_task() {
  printf "\033[0;34m--> %s\033[0m\n" "$*"
}

error() {
  printf "\033[0;31m%s\033[0m\n" "$*" >&2
  exit 1
}

# -e: exit on error
# -u: exit on unset variables
set -e

if [ -f /etc/debian_version ]; then
  echo_task "Checking and installing required dependencies if missing"

  # Array to store dependencies to be installed
  dependencies=()

  # Function to add dependency if missing
  install_if_missing() {
    if ! command -v "$1" >/dev/null; then
      dependencies+=("$1")
    else
      echo_task "$1 is already installed"
    fi
  }

  # Check and add dependencies
  install_if_missing zsh
  install_if_missing git
  install_if_missing wget
  install_if_missing curl

  # If there are dependencies to install, do it in one go
  if [ ${#dependencies[@]} -gt 0 ]; then
    echo_task "Installing missing dependencies: ${dependencies[*]}"
    sudo apt-get update
    sudo apt-get -y install "${dependencies[@]}"
  fi

  # Change shell to zsh
  echo_task "Changing shell to zsh"
  sudo chsh -s /usr/bin/zsh $(whoami)
fi

if [ "$(ps -p $$ -o comm=)" = "bash" ]; then
  echo "Restarting script with zsh..."
  exec /usr/bin/zsh "$0" "$@"
fi

# Install Chezmoi if not already installed
if ! chezmoi="$(command -v chezmoi)"; then
  bin_dir="${HOME}/.local/bin"
  mkdir -p "${bin_dir}"
  chezmoi="${bin_dir}/chezmoi"
  echo_task "Installing chezmoi to ${chezmoi}"
  if command -v curl >/dev/null; then
    chezmoi_installer="$(curl -fsSL https://git.io/chezmoi)"
  elif command -v wget >/dev/null; then
    chezmoi_installer="$(wget -qO- https://git.io/chezmoi)"
  else
    error "To install chezmoi, you must have curl or wget."
  fi
  sh -c "${chezmoi_installer}" -- -b "${bin_dir}"
  unset chezmoi_installer bin_dir
fi

chezmoi_args=""
chezmoi_init_args=""

if [ -n "${DOTFILES_DEBUG:-}" ]; then
  chezmoi_args="${chezmoi_args} --debug"
fi

if [ -n "${DOTFILES_VERBOSE:-}" ]; then
  chezmoi_args="${chezmoi_args} --verbose"
fi

if [ -n "${DOTFILES_NO_TTY:-}" ]; then
  chezmoi_args="${chezmoi_args} --no-tty"
fi

if [ -n "${DOTFILES_BRANCH:-}" ]; then
  echo_task "Chezmoi branch: ${DOTFILES_BRANCH}"
  chezmoi_init_args="${chezmoi_init_args} --branch ${DOTFILES_BRANCH}"
fi

# If DOTFILES_LOCAL_COPY is not set, we init from the main benrowe/dotfiles repository
if [ -z "${DOTFILES_LOCAL_COPY:-}" ]; then
  chezmoi_init_args="${chezmoi_init_args} benrowe"
fi

echo_task "Running chezmoi init"
"${chezmoi}" init ${chezmoi_init_args} ${chezmoi_args}

echo_task "Running chezmoi apply"
"${chezmoi}" apply ${chezmoi_args}
