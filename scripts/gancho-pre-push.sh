#!/usr/bin/env bash
exec bash "$(dirname "${BASH_SOURCE[0]}")/ganchos.sh" rodar pre-push "$@"
