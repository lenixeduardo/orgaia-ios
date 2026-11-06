#!/usr/bin/env bash
# Publish OrgaIA to a NEW private GitHub repository under lenixeduardo.
set -euo pipefail

REPO="lenixeduardo/orgaia-ios"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) não está instalado. Instale em https://cli.github.com/" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "Execute 'gh auth login' para autenticar na conta GitHub." >&2
  exit 1
fi

OWNER="$(gh api user --jq '.login')"
if [[ "$OWNER" != "lenixeduardo" ]]; then
  echo "Conta GitHub autenticada: $OWNER; esperado: lenixeduardo. Publicação cancelada." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git init -b main
fi
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  echo "O projeto precisa ter um commit inicial antes da publicação." >&2
  exit 1
fi

if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "O repositório $REPO já existe. Não será recriado ou sobrescrito." >&2
  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/$REPO.git"
  fi
  echo "Confira o conteúdo antes de executar: git push -u origin main"
  exit 0
fi

echo "Criando repositório privado $REPO e publicando a branch main..."
gh repo create "$REPO" --private --source=. --remote=origin --push

echo "Publicado: https://github.com/$REPO"
