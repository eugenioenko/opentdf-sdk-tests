#!/usr/bin/env bash
#
# Shared shell wrapper for the Goalchemy-generated SDKs (sdk/gc*): each
# Makefile copies it next to its native `otdfgc` binary as cli.sh.
#
# Usage: ./cli.sh <encrypt | decrypt> <src-file> <dst-file> <fmt>
#
# Extended Utilities:
#
# ./cli.sh supports <feature>
#   Check if the SDK supports a specific feature. Known feature names are
#   answered by `otdfgc supports`, which reads the SDK's SupportedFeatures();
#   unknown names exit 2.
#
# Extended Configuration (same contract as sdk/go/cli.sh):
#  XT_WITH_ECDSA_BINDING [boolean] - Use ECDSA binding for encryption
#  XT_WITH_ECWRAP [boolean] - Use EC wrap for encryption/decryption
#  XT_WITH_VERIFY_ASSERTIONS [boolean] - Verify assertions during decryption
#  XT_WITH_ASSERTIONS [string] - Path to assertions file, or JSON encoded as string
#  XT_WITH_ASSERTION_VERIFICATION_KEYS [string] - Path to assertion verification private key file
#  XT_WITH_ATTRIBUTES [string] - Attributes to be used for encryption
#  XT_WITH_MIME_TYPE [string] - MIME type for the encrypted file
#  XT_WITH_TARGET_MODE [string] - TDF spec version to write
#  XT_WITH_PLAINTEXT_POLICY [boolean] - Write the policy in plaintext
#  XT_WITH_KAS_ALLOWLIST / XT_WITH_KAS_ALLOW_LIST [string] - KAS allowlist for decryption
#  XT_WITH_IGNORE_KAS_ALLOWLIST [boolean] - Bypass the KAS allowlist
#  XT_WITH_DPOP [string] - Enable DPoP token binding; value selects algorithm (e.g. ES256)
#  XT_WITH_DPOP_KEY [string] - Path to PEM-encoded private key for DPoP signing
#
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

cmd=("$SCRIPT_DIR"/otdfgc)
if [[ ! -x "${cmd[0]}" ]]; then
  echo "otdfgc not built at ${cmd[0]}; run make in sdk/<type>"
  exit 1
fi

if [ "$1" == "supports" ]; then
  case "$2" in
    assertions | assertion_verification | attribute_traversal | audit_logging | autoconfigure | \
      better-messages-2024 | bulk_rewrap | chunky | connectrpc | dpop | dpop_nonce_challenge | ecwrap | \
      gmac_root_rejected | hexless | hexaflexible | kasallowlist | kas_uri_from_kao | key_management | \
      mechanism-rsa-4096 | mechanism-ec-curves-384-521 | mechanism-xwing | mechanism-secpmlkem | \
      mechanism-mlkem | multikao | ns_grants | obligations | zip64-at-2gib)
      "${cmd[@]}" supports "$2"
      exit $?
      ;;
    *)
      echo "Unknown feature: $2"
      exit 2
      ;;
  esac
fi

XTEST_DIR="$SCRIPT_DIR"
while [ "$XTEST_DIR" != "/" ]; do
  if [ -f "$XTEST_DIR/pyproject.toml" ] && grep -q 'name = "xtest"' "$XTEST_DIR/pyproject.toml"; then
    break
  fi
  XTEST_DIR=$(dirname "$XTEST_DIR")
done

if [ "$XTEST_DIR" = "/" ]; then
  echo "xtest root (pyproject.toml with name = \"xtest\") not found."
  exit 1
fi

if [ -f "$XTEST_DIR/test.env" ]; then
  # shellcheck disable=SC1091
  source "$XTEST_DIR/test.env"
else
  echo "test.env not found in xtest root: $XTEST_DIR"
  exit 1
fi

args=(
  --out "$3"
  --host "$PLATFORMURL"
  --tls-no-verify
  --with-client-creds '{"clientId":"'"$CLIENTID"'","clientSecret":"'"$CLIENTSECRET"'"}'
)
if [ "$4" != "ztdf" ]; then
  echo "Unsupported container format: $4"
  exit 2
fi
if [ -n "$XT_WITH_DPOP" ]; then
  args+=(--dpop "$XT_WITH_DPOP")
fi
if [ -n "$XT_WITH_DPOP_KEY" ]; then
  args+=(--dpop-key "$XT_WITH_DPOP_KEY")
fi

if [ "$1" == "encrypt" ]; then
  if [ -n "$XT_WITH_MIME_TYPE" ]; then
    args+=(--mime-type "$XT_WITH_MIME_TYPE")
  fi
  if [ -n "$XT_WITH_ATTRIBUTES" ]; then
    args+=(--attr "$XT_WITH_ATTRIBUTES")
  fi
  if [ -n "$XT_WITH_ASSERTIONS" ]; then
    args+=(--with-assertions "$XT_WITH_ASSERTIONS")
  fi
  if [ "$XT_WITH_ECWRAP" == 'true' ]; then
    args+=(--wrapping-key-algorithm "ec:secp256r1")
  fi
  if [ "$XT_WITH_ECDSA_BINDING" == "true" ]; then
    args+=(--ecdsa-binding)
  fi
  if [ "$XT_WITH_PLAINTEXT_POLICY" == "true" ]; then
    args+=(--policy-mode plaintext)
  fi
  if [ -n "$XT_WITH_TARGET_MODE" ]; then
    args+=(--target-mode "$XT_WITH_TARGET_MODE")
  fi
  echo "${cmd[@]}" encrypt "${args[@]}" "$2"
  "${cmd[@]}" encrypt "${args[@]}" "$2"
elif [ "$1" == "decrypt" ]; then
  if [ -n "$XT_WITH_ASSERTION_VERIFICATION_KEYS" ]; then
    args+=(--with-assertion-verification-keys "$XT_WITH_ASSERTION_VERIFICATION_KEYS")
  fi
  if [ "$XT_WITH_ECWRAP" == 'true' ]; then
    args+=(--session-key-algorithm "ec:secp256r1")
  fi
  if [ "$XT_WITH_VERIFY_ASSERTIONS" == 'false' ]; then
    args+=(--no-verify-assertions)
  fi
  # tdfs.py sets XT_WITH_KAS_ALLOWLIST; the older shims documented XT_WITH_KAS_ALLOW_LIST.
  if [ -n "${XT_WITH_KAS_ALLOWLIST:-$XT_WITH_KAS_ALLOW_LIST}" ]; then
    args+=(--kas-allowlist "${XT_WITH_KAS_ALLOWLIST:-$XT_WITH_KAS_ALLOW_LIST}")
  fi
  # bypassing the allowlist may expose potential security risks
  if [ "$XT_WITH_IGNORE_KAS_ALLOWLIST" == "true" ]; then
    args+=(--kas-allowlist '*')
  fi
  echo "${cmd[@]}" decrypt "${args[@]}" "$2"
  "${cmd[@]}" decrypt "${args[@]}" "$2"
else
  echo "Incorrect argument provided"
  exit 1
fi
