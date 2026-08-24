#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CIQ_USER_HOME_DIR="${HOME}"
CIQ_CONFIG_FILE="${CIQ_USER_HOME_DIR}/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
CIQ_LOCAL_ENV_FILE="${PROJECT_DIR}/.ciq.local.env"

die() {
    echo "ciq: $*" >&2
    exit 2
}

if [[ ! -f "${CIQ_CONFIG_FILE}" ]]; then
    die "Connect IQ SDK configuration was not found at ${CIQ_CONFIG_FILE}"
fi

load_local_config() {
    [[ -f "${CIQ_LOCAL_ENV_FILE}" ]] || return

    while IFS='=' read -r name value || [[ -n "${name}" ]]; do
        [[ -z "${name}" || "${name}" == \#* ]] && continue

        case "${name}" in
            CIQ_DEVELOPER_KEY|CIQ_DEVICE)
                value="${value#\"}"
                value="${value%\"}"

                if [[ -z "${!name:-}" ]]; then
                    export "${name}=${value}"
                fi
                ;;
            *)
                die "Unsupported setting in ${CIQ_LOCAL_ENV_FILE}: ${name}"
                ;;
        esac
    done < "${CIQ_LOCAL_ENV_FILE}"
}

load_local_config

CIQ_SDK_DIR="$(<"${CIQ_CONFIG_FILE}")"
CIQ_BIN_DIR="${CIQ_SDK_DIR}/bin"
CIQ_DEVICE="${CIQ_DEVICE:-fr265}"
CIQ_DEVELOPER_KEY="${CIQ_DEVELOPER_KEY:-}"

DIAGNOSTIC_JUNGLE="${PROJECT_DIR}/garmin/diagnostic/monkey.jungle"
DIAGNOSTIC_PRG="${PROJECT_DIR}/garmin/diagnostic/bin/diagnostic.prg"
DIAGNOSTIC_TEST_PRG="${PROJECT_DIR}/garmin/diagnostic/bin/test_${CIQ_DEVICE}_diagnostic.prg"
DATAFIELD_JUNGLE="${PROJECT_DIR}/garmin/datafield/monkey.jungle"
DATAFIELD_PRG="${PROJECT_DIR}/garmin/datafield/bin/ftmsDataField_${CIQ_DEVICE}.prg"

require_tool() {
    local tool="$1"

    [[ -x "${CIQ_BIN_DIR}/${tool}" ]] || die "Connect IQ tool not found: ${CIQ_BIN_DIR}/${tool}"
}

require_key() {
    [[ -n "${CIQ_DEVELOPER_KEY}" ]] || die "Set CIQ_DEVELOPER_KEY in .ciq.local.env or the Run Configuration environment"
    [[ -f "${CIQ_DEVELOPER_KEY}" ]] || die "Developer key does not exist: ${CIQ_DEVELOPER_KEY}"
}

build_diagnostic() {
    require_tool monkeyc
    require_key
    mkdir -p "${PROJECT_DIR}/garmin/diagnostic/bin"

    "${CIQ_BIN_DIR}/monkeyc" \
        -d "${CIQ_DEVICE}" \
        -f "${DIAGNOSTIC_JUNGLE}" \
        -o "${DIAGNOSTIC_PRG}" \
        -y "${CIQ_DEVELOPER_KEY}"
}

build_diagnostic_tests() {
    require_tool monkeyc
    require_key
    mkdir -p "${PROJECT_DIR}/garmin/diagnostic/bin"

    "${CIQ_BIN_DIR}/monkeyc" \
        -d "${CIQ_DEVICE}" \
        -t \
        -f "${DIAGNOSTIC_JUNGLE}" \
        -o "${DIAGNOSTIC_TEST_PRG}" \
        -y "${CIQ_DEVELOPER_KEY}"
}

build_datafield() {
    require_tool monkeyc
    require_key
    mkdir -p "${PROJECT_DIR}/garmin/datafield/bin"

    "${CIQ_BIN_DIR}/monkeyc" \
        -d "${CIQ_DEVICE}" \
        -f "${DATAFIELD_JUNGLE}" \
        -o "${DATAFIELD_PRG}" \
        -y "${CIQ_DEVELOPER_KEY}"
}

run_prg() {
    local prg="$1"

    require_tool monkeydo
    [[ -f "${prg}" ]] || die "PRG not found. Build it first: ${prg}"
    "${CIQ_BIN_DIR}/monkeydo" "${prg}" "${CIQ_DEVICE}"
}

run_tests() {
    require_tool monkeydo
    [[ -f "${DIAGNOSTIC_TEST_PRG}" ]] || die "Test PRG not found. Build it first: ${DIAGNOSTIC_TEST_PRG}"
    "${CIQ_BIN_DIR}/monkeydo" "${DIAGNOSTIC_TEST_PRG}" "${CIQ_DEVICE}" -t
}

case "${1:-help}" in
    simulator)
        require_tool connectiq
        exec "${CIQ_BIN_DIR}/connectiq"
        ;;
    sdk-version)
        require_tool monkeyc
        exec "${CIQ_BIN_DIR}/monkeyc" -v
        ;;
    build-diagnostic)
        build_diagnostic
        ;;
    run-diagnostic)
        run_prg "${DIAGNOSTIC_PRG}"
        ;;
    build-run-diagnostic)
        build_diagnostic
        run_prg "${DIAGNOSTIC_PRG}"
        ;;
    build-diagnostic-tests)
        build_diagnostic_tests
        ;;
    run-diagnostic-tests)
        run_tests
        ;;
    build-run-diagnostic-tests)
        build_diagnostic_tests
        run_tests
        ;;
    build-datafield)
        build_datafield
        ;;
    run-datafield)
        run_prg "${DATAFIELD_PRG}"
        ;;
    build-run-datafield)
        build_datafield
        run_prg "${DATAFIELD_PRG}"
        ;;
    help|*)
        cat <<'HELP'
Usage: tools/ciq.sh <command>

Commands:
  simulator                    Launch the Connect IQ simulator
  sdk-version                  Print the active Connect IQ SDK version
  build-diagnostic             Build the diagnostic watch app
  run-diagnostic               Run the existing diagnostic PRG
  build-run-diagnostic         Build and run the diagnostic watch app
  build-diagnostic-tests       Build the diagnostic app with unit tests
  run-diagnostic-tests         Run the existing diagnostic unit-test PRG
  build-run-diagnostic-tests   Build and run diagnostic unit tests
  build-datafield              Build the data-field app
  run-datafield                Run the existing data-field PRG
  build-run-datafield          Build and run the data-field app

Build commands require CIQ_DEVELOPER_KEY to point to a Connect IQ .der key.
CIQ_DEVICE defaults to fr265 and may be set to fr265s.
HELP
        exit 2
        ;;
esac
