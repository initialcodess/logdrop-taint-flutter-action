#!/usr/bin/env bash
# Installs the LogDrop Flutter taint analyzer: one self-contained binary that needs no
# Dart SDK, no pub get and none of the project's dependencies.
#
#   LOGDROP_VERSION=v1.0.3 LOGDROP_DIR="$HOME/.logdrop" ./install-logdrop-taint.sh
#
# Used by the GitHub Action and by the CircleCI, GitLab, Jenkins and Bitrise recipes
# beside it, so every CI system installs the analyzer the same way.
set -euo pipefail

VERSION="${LOGDROP_VERSION:-v1.0.3}"
DIR="${LOGDROP_DIR:-$HOME/.logdrop}"
REPO="initialcodess/logdrop-taint-flutter-action"

if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid LOGDROP_VERSION: '$VERSION' (expected v1.2.3)" >&2
  exit 1
fi

# The analyzer is compiled ahead of time, so the binary is per-platform - unlike the
# Android jar and the React Native bundle, which carry their own runtime. Picked here
# rather than by the caller, because getting it wrong produces "cannot execute binary
# file", which says nothing about what went wrong.
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)   TARGET="linux-x64" ;;
  Darwin-arm64)   TARGET="macos-arm64" ;;
  Darwin-x86_64)
    # Rosetta reports x86_64 on an Apple Silicon Mac. The arm64 build runs there under
    # translation; an x86_64 build of this analyzer is not published.
    TARGET="macos-arm64" ;;
  *)
    echo "LogDrop: no published build for $(uname -s)-$(uname -m)." >&2
    echo "         Published targets: linux-x64, macos-arm64." >&2
    exit 1 ;;
esac

BIN="logdrop-taint-flutter-${VERSION}-${TARGET}"
mkdir -p "$DIR"

# EXPECTED CHECKSUMS — and the whole point is WHERE this table lives.
#
# The binary could be checked against a .sha256 downloaded from the same release. That
# proves a download did not arrive corrupt, and nothing more: whoever can replace the
# binary in a release can replace the checksum beside it, and the check still passes. A
# verifier that ships with the thing it verifies is not a verifier.
#
# So the expected value lives HERE, in the script the customer already pinned. Pin the
# action by commit SHA and this line is fixed at that commit: swapping the release is no
# longer enough, because the attacker would also have to change a commit you have named.
# That is why the README asks for a SHA rather than @v1.
#
# It does not defend against someone who can push to THIS repository. Nothing in a
# repository can. Pinning is what limits that, and it is the customer's move.
expected_sha() {
  case "$1-$2" in
    v0.1.0-linux-x64)   echo "fc9855b99859e04f731ba8abf332fac8cb0249851052607728e6783ad7f73769" ;;
    v0.1.0-macos-arm64) echo "7eaaf57ceb53351eafb6334dbef665ab7e655d02336176a1362508e09d7dda25" ;;
    v0.1.1-linux-x64)   echo "0727f90886662a34b3018222f9199607e90a7e6717e43b5177a24cf4b49c0cf9" ;;
    v0.1.1-macos-arm64) echo "8ca8c570b71b488d0a58ba2af407335bcdbcb280a774e91fc94a9e7150d35a4d" ;;
    v1.0.0-linux-x64)   echo "5427668fc8bfefa28a2647354a352828e32b3b6de3275899ef37bb5b25aa05e8" ;;
    v1.0.0-macos-arm64) echo "066466001092d0c64b7a8b8fa94499d92544e22d7221e90400cc34f4a4477d0a" ;;
    v1.0.1-linux-x64)   echo "86cac88961bdeecbf7221072241f149a9d6bd9ab4d30cfb26229261c2a774360" ;;
    v1.0.1-macos-arm64) echo "a638033fa763e12ef3508c0c6addbd291ecfeeb5ad04a0245d939ea6e243e186" ;;
    v1.0.2-linux-x64)   echo "f113d384986281d8c13047e38d171d4dd1543760632e2ac9c887f066617dc165" ;;
    v1.0.2-macos-arm64) echo "934a8850e1b3b896861dc21887161388fd55c7f41a63f280bfbb863c4ba6cb13" ;;
    v1.0.3-linux-x64)   echo "935cae593ee25ecc233d2d7140e42ffe28835804b0bf7f19e631af9c545ee39b" ;;
    v1.0.3-macos-arm64) echo "f80cf1f6772b2a595c9a405b30b29e2456bec049def75cbcb76170b856a222ba" ;;
    *)                  echo "" ;;
  esac
}
EXPECTED="$(expected_sha "$VERSION" "$TARGET")"

# STRICT MODE, checked BEFORE anything is fetched. Advisory by default, hard gate on
# request - the same shape as --fail-on, because the default that serves the most people
# is the one that does not break a pipeline over something its owner cannot fix today.
if [ -z "$EXPECTED" ] && [ "${LOGDROP_REQUIRE_PINNED_CHECKSUM:-false}" = "true" ]; then
  echo "LogDrop: NO PINNED CHECKSUM for $VERSION on $TARGET, and one was required." >&2
  echo "         This copy of the installer predates that version. Update the action," >&2
  echo "         or unset require-pinned-checksum to accept the published checksum." >&2
  exit 1
fi

# Already installed and already verified: do not download it again.
if [ -x "$DIR/$BIN" ] && [ -n "$EXPECTED" ]; then
  if echo "$EXPECTED  $DIR/$BIN" | shasum -a 256 -c - >/dev/null 2>&1; then
    echo "LogDrop: reusing the verified copy of $VERSION"
    exit 0
  fi
fi

BASE="https://github.com/${REPO}/releases/download/${VERSION}"
echo "LogDrop: downloading $BIN"
curl -fsSL --retry 3 --retry-delay 2 -o "$DIR/$BIN" "$BASE/$BIN"

if [ -n "$EXPECTED" ]; then
  if ! echo "$EXPECTED  $DIR/$BIN" | shasum -a 256 -c - >/dev/null 2>&1; then
    rm -f "$DIR/$BIN"
    echo "LogDrop: CHECKSUM MISMATCH - the download was NOT what this action expects." >&2
    echo "         Expected $EXPECTED" >&2
    echo "         The file has been deleted rather than run. Report this to" >&2
    echo "         destek@initialcode.io before trying again." >&2
    exit 1
  fi
  echo "LogDrop: checksum verified against the copy pinned in this action"
else
  # No pinned value: fall back to the checksum published beside the release, and SAY
  # what that is worth. It catches a corrupt download. It does not catch a replaced one,
  # because the same person would publish both.
  curl -fsSL --retry 3 --retry-delay 2 -o "$DIR/$BIN.sha256" "$BASE/$BIN.sha256"
  # The published file names the artifact as it was built, which is not the name it was
  # saved under here. Compare the hash itself rather than trusting the filename to match.
  published=$(cut -d' ' -f1 < "$DIR/$BIN.sha256")
  actual=$(shasum -a 256 "$DIR/$BIN" | cut -d' ' -f1)
  if [ "$published" != "$actual" ]; then
    rm -f "$DIR/$BIN"
    echo "LogDrop: the download does not match its own published checksum." >&2
    exit 1
  fi
  echo "LogDrop: verified against the PUBLISHED checksum - this detects a corrupt"
  echo "         download, not a replaced one. Update the action to pin $VERSION."
fi

chmod +x "$DIR/$BIN"
echo "LogDrop: installed $DIR/$BIN"
