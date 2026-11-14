#!/bin/bash
set -euo pipefail
# Local packaging only. Public updates need a separate project setup.
exec bash "$(dirname "$0")/build-review.sh" --package-only "$@"
