#!/usr/bin/env bash
# release.sh vX.Y.Z — tag, push, create the GitHub release with the zip, and write the
# Homebrew formula with the sha256 DERIVED from the published tarball (never hand-typed).
#   TAP_DIR   path to a checkout of mohan-n-swamy/homebrew-tap (default ../homebrew-tap)
set -euo pipefail
V="${1:?usage: release.sh vX.Y.Z}"; V="${V#v}"
REPO="mohan-n-swamy/rigor"
TAP_DIR="${TAP_DIR:-$(cd "$(dirname "$0")/.." && pwd)/homebrew-tap}"

[ -z "$(git status --porcelain)" ] || { echo "working tree dirty; commit first" >&2; exit 1; }
echo "$V" > VERSION
bash tests/test.sh
git add VERSION && git commit -q -m "release v$V" || true
git tag -a "v$V" -m "rigor v$V"
git push origin HEAD --tags
make dist
gh release create "v$V" "dist/rigor-v$V.zip" --title "rigor v$V" --notes "See CHANGELOG.md" --repo "$REPO"

URL="https://github.com/$REPO/archive/refs/tags/v$V.tar.gz"
SHA=$(curl -sL "$URL" | shasum -a 256 | cut -d' ' -f1)
[ -n "$SHA" ] || { echo "could not fetch $URL" >&2; exit 1; }

mkdir -p "$TAP_DIR/Formula"
cat > "$TAP_DIR/Formula/rigor.rb" <<EOF
class Rigor < Formula
  desc "The Rigor protocol for Claude Code: six answers before the work, evidence before 'done'"
  homepage "https://github.com/$REPO"
  url "$URL"
  sha256 "$SHA"
  license "MIT"


  def install
    libexec.install Dir["*"]
    (bin/"rigor").write <<~EOS
      #!/bin/bash
      exec bash "#{libexec}/bin/rigor" "\$@"
    EOS
  end

  def caveats
    <<~EOS
      Wire the hooks into your Claude Code setup (idempotent, reversible with 'rigor uninstall'):
        rigor install
      Then restart Claude Code sessions.
    EOS
  end

  test do
    assert_match "PASS red: bare template rejected", shell_output("#{bin}/rigor self-test")
  end
end
EOF
echo "formula written: $TAP_DIR/Formula/rigor.rb (sha $SHA)"
echo "next: cd $TAP_DIR && git add Formula/rigor.rb && git commit -m 'rigor v$V' && git push"
