#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README_PATH="${1:-${ROOT_DIR}/README.mbt.md}"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

if [[ ! -f "${README_PATH}" ]]; then
  echo "README file not found: ${README_PATH}" >&2
  exit 1
fi

required_blocks=(
  "src/passes/pkg.generated.mbti"
  "src/validate/pkg.generated.mbti"
  "src/binary/pkg.generated.mbti"
  "src/wast/pkg.generated.mbti"
  "src/wat/pkg.generated.mbti"
  "src/ir/pkg.generated.mbti"
  "src/transformer/pkg.generated.mbti"
  "src/cmd/pkg.generated.mbti"
)

line_no=0
marker_count=0
signature_count=0
pending_marker_path=""
pending_marker_line=0
active_interface_path=""
active_signature_count=0
seen_paths=()
errors=()

while IFS= read -r line || [[ -n "${line}" ]]; do
  line_no=$((line_no + 1))
  trimmed="$(trim "${line}")"

  if [[ -n "${active_interface_path}" ]]; then
    if [[ "${trimmed}" == '```' ]]; then
      if ((active_signature_count == 0)); then
        errors+=(
          "README_API_VERIFY block for ${active_interface_path} has no signatures (line ${line_no})"
        )
      fi
      active_interface_path=""
      active_signature_count=0
      continue
    fi

    if [[ -n "${trimmed}" ]]; then
      interface_file="${ROOT_DIR}/${active_interface_path}"
      if [[ ! -f "${interface_file}" ]]; then
        errors+=("missing interface file: ${active_interface_path}")
      elif ! grep -Fqx -- "${trimmed}" "${interface_file}"; then
        errors+=(
          "missing signature in ${active_interface_path} (README line ${line_no}): ${trimmed}"
        )
      fi
      active_signature_count=$((active_signature_count + 1))
      signature_count=$((signature_count + 1))
    fi
    continue
  fi

  if [[ -n "${pending_marker_path}" ]]; then
    if [[ -z "${trimmed}" ]]; then
      continue
    fi
    if [[ "${trimmed}" == '```mbti' ]]; then
      active_interface_path="${pending_marker_path}"
      pending_marker_path=""
      pending_marker_line=0
      active_signature_count=0
      marker_count=$((marker_count + 1))
      seen_paths+=("${active_interface_path}")
      continue
    fi
    errors+=(
      "README_API_VERIFY marker at line ${pending_marker_line} must be followed by \`\`\`mbti (found: ${trimmed})"
    )
    pending_marker_path=""
    pending_marker_line=0
  fi

  if [[ "${trimmed}" =~ ^\<\!--[[:space:]]README_API_VERIFY[[:space:]]+([^[:space:]]+)[[:space:]]--\>$ ]]; then
    pending_marker_path="${BASH_REMATCH[1]}"
    pending_marker_line=${line_no}
  fi
done <"${README_PATH}"

if [[ -n "${pending_marker_path}" ]]; then
  errors+=(
    "README_API_VERIFY marker at line ${pending_marker_line} is missing a following \`\`\`mbti block"
  )
fi

if [[ -n "${active_interface_path}" ]]; then
  errors+=(
    "README_API_VERIFY block for ${active_interface_path} is missing a closing \`\`\` fence"
  )
fi

if ((marker_count == 0)); then
  errors+=("README contains no README_API_VERIFY blocks")
fi

for required in "${required_blocks[@]}"; do
  found=false
  for seen in "${seen_paths[@]}"; do
    if [[ "${seen}" == "${required}" ]]; then
      found=true
      break
    fi
  done
  if [[ "${found}" == false ]]; then
    errors+=("missing required README_API_VERIFY block: ${required}")
  fi
done

if ((${#errors[@]} > 0)); then
  for error_msg in "${errors[@]}"; do
    echo "ERROR: ${error_msg}" >&2
  done
  exit 1
fi

echo "README API sync check passed: ${marker_count} block(s), ${signature_count} signature line(s)."
