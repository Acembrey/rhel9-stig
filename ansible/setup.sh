#!/usr/bin/env bash
# =============================================================================
# ansible/setup.sh
#
# Builds a project-local Python virtual environment for Ansible, pinned to
# the version that aligns with this project's collection requirements.
#
# WHY 2.16, NOT "2.14+":
#   - requirements.yml pins community.general to ">=8.0.0,<10.0.0"
#   - community.general 10.x dropped support for ansible-core 2.15/2.16 in
#     favor of 2.17+. Pinning ansible-core to 2.16.x keeps it inside the
#     supported range for our community.general pin.
#   - Red Hat AAP's own support matrix treats ansible-core 2.16 as the
#     current supported line for RHEL 9 control nodes; 2.17 has already
#     been dropped from support, and 2.15 support ends June 2026.
#   - If you deliberately bump community.general past 10.0.0 later, you
#     MUST also bump ANSIBLE_CORE_VERSION below to 2.17+ in lockstep, or
#     you'll reproduce the exact "Collection does not support this Ansible
#     version" warning this project hit previously.
#
# USAGE:
#   cd ansible/
#   ./setup.sh
#   source venv/bin/activate
#
# Re-running is safe — it rebuilds the venv from scratch (idempotent).
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Pinned versions — keep these in sync with ../requirements.yml
# ---------------------------------------------------------------------------
ANSIBLE_CORE_VERSION="2.16.*"     # tracks the 2.16.x line, latest patch
VENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/venv"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements.yml"

# ---------------------------------------------------------------------------
# 1. Locate a usable Python interpreter (3.10–3.12 supports ansible-core 2.16)
# ---------------------------------------------------------------------------
find_python() {
    for candidate in python3.12 python3.11 python3.10 python3; do
        if command -v "${candidate}" >/dev/null 2>&1; then
            echo "${candidate}"
            return 0
        fi
    done
    echo "ERROR: No suitable python3 interpreter found (need 3.10-3.12)." >&2
    exit 1
}

PYTHON_BIN="$(find_python)"
echo "==> Using interpreter: $(${PYTHON_BIN} --version) ($(command -v "${PYTHON_BIN}"))"

# ---------------------------------------------------------------------------
# 2. Build the venv (fresh each run for reproducibility)
# ---------------------------------------------------------------------------
if [ -d "${VENV_DIR}" ]; then
    echo "==> Removing existing venv at ${VENV_DIR}"
    rm -rf "${VENV_DIR}"
fi

echo "==> Creating venv at ${VENV_DIR}"
"${PYTHON_BIN}" -m venv "${VENV_DIR}" # shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "==> Upgrading pip/setuptools/wheel"
pip install --upgrade pip setuptools wheel >/dev/null

# ---------------------------------------------------------------------------
# 3. Install ansible-core, pinned
# ---------------------------------------------------------------------------
echo "==> Installing ansible-core==${ANSIBLE_CORE_VERSION}"
pip install "ansible-core==${ANSIBLE_CORE_VERSION}"

# ---------------------------------------------------------------------------
# 4. Summary
# ---------------------------------------------------------------------------
echo ""
echo "==> Done."
echo "    ansible-core: $(ansible --version | head -n1)"
echo "    venv path:    ${VENV_DIR}"
echo ""
echo "Activate with:"
echo "    source ${VENV_DIR}/bin/activate"
