#!/usr/bin/env bash
# Zip / git-clone entry point. Same as: bin/rigor install
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/rigor" install "$@"
