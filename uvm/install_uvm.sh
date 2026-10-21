#!/bin/sh
set -eu

version=2020.3.1
archive="UVM-1800.2-${version}.tar.gz"
url="https://www.accellera.org/images/downloads/standards/uvm/${archive}"
sha256=0d6a2ca5811c787e5aa1e945abaaaa5d5c295148d5e704c9fa910d7b288cbcf7
install_root=${UVM_INSTALL_ROOT:-"${HOME}/.local/share/uvm"}
destination="${install_root}/1800.2-${version}"
tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT HUP INT TERM

if [ -f "${destination}/src/uvm_pkg.sv" ]; then
    printf 'UVM source already installed at %s/src\n' "${destination}"
    exit 0
fi

mkdir -p "${install_root}"
if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "${url}" -o "${tmp_dir}/${archive}"
elif command -v wget >/dev/null 2>&1; then
    wget --quiet "${url}" -O "${tmp_dir}/${archive}"
else
    echo 'Install curl or wget to download UVM.' >&2
    exit 1
fi

printf '%s  %s\n' "${sha256}" "${tmp_dir}/${archive}" | sha256sum --check --status || {
    echo 'UVM archive SHA-256 verification failed.' >&2
    exit 1
}
tar -xzf "${tmp_dir}/${archive}" -C "${install_root}"
test -f "${destination}/src/uvm_pkg.sv"
printf 'Installed UVM source at %s/src\n' "${destination}"
printf 'Run with: UVM_HOME=%s/src make -C uvm run\n' "${destination}"
