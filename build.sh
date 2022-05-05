#!/usr/bin/env bash
set -Eeuxo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
WORK_DIR=$(pwd)

git pull --recurse-submodules

GEN_DIR="${WORK_DIR}/_gen"

rm -rf "${GEN_DIR}/" || true
git worktree add --checkout -f -B gh-pages "${GEN_DIR}/" gh-pages
cd "${GEN_DIR}/"
git rm -r --cached "./*" || true
rm -rf "./*" || true
cd "${WORK_DIR}"

git submodule update --remote

python3 -m pip install --user poetry

for dPath in $(find . -maxdepth 2 -name 'docs' -not -path "./_gen/*" -print); do
    (
        cd "${WORK_DIR}/${dPath}"
        poetry install
    ) || (
        cd "${WORK_DIR}/${dPath}/.."
        poetry install
    ) || (echo "no poetry install" && exit 1)
    cd "${WORK_DIR}/${dPath}"
    poetry run make html
    mkdir -p "${GEN_DIR}/${dPath}/"
    cp -ar build/html/. "${GEN_DIR}/${dPath}/.." || cp -ar _build/html/. "${GEN_DIR}/${dPath}/.." || (echo "no build/html folder" && exit 1)
done

(
    cd "${WORK_DIR}/_index"
    poetry install
) || (echo "no poetry install" && exit 1)
cd "${WORK_DIR}/_index"
poetry run make html
cp -ar build/html/. "${GEN_DIR}/" || cp -ar _build/html/. "${GEN_DIR}/" || (echo "no build/html folder" && exit 1)

cd "${GEN_DIR}" || (echo "no ${GEN_DIR} found" && exit 1)

git add .
git commit -m "Update docs - Build $(date '+%Y%m%d%H%M%S')"
git branch --set-upstream-to=origin/gh-pages gh-pages
git push

cd "${WORK_DIR}"
git add .
git commit -m "Update docs - Build $(date '+%Y%m%d%H%M%S')"
git push
