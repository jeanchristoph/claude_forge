#!/usr/bin/env bash
set -e
exec bash "$(cd "$(dirname "$0")" && pwd)/install/install.sh"
