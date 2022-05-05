#!/usr/bin/env bash
set -Eeuxo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
WORK_DIR=$(pwd)

command -v xsltproc || (echo "Please install 'xsltproc': sudo apt-get install xsltproc" && exit 1)
command -v gh || (echo "Please install 'gh': see https://cli.github.com/manual/installation" && exit 1)

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

cd "${WORK_DIR}"

dl_gmp_doc() {
    GMP_VERSION=$1
    runID=$(gh run list -R greenbone/gvmd -L 10 -w build-docs.yml --json 'databaseId' -b ${GMP_VERSION} -q 'first(.[]).databaseId')
    if [ "${GMP_VERSION}" == "main" ]; then
        GMP_VERSION=unstable
    fi
    gh run download $runID -D "${GEN_DIR}/gmp_doc/tmp/${GMP_VERSION}" -R greenbone/gvmd
    mkdir -p "${GEN_DIR}/protocol/${GMP_VERSION}/"
    mv "${GEN_DIR}/gmp_doc/tmp/${GMP_VERSION}/gmp.html/gmp.html" "${GEN_DIR}/protocol/${GMP_VERSION}/"
    rm -rf "${GEN_DIR}/gmp_doc/tmp/${GMP_VERSION}/gmp.html"
}
dl_gmp_doc "oldstable"
dl_gmp_doc "stable"
dl_gmp_doc "main"

gh repo clone greenbone/ospd-openvas
cd ospd-openvas
dl_osp_doc() {
    OSP_VERSION=$1
    git switch ${OSP_VERSION}
    if [ "${OSP_VERSION}" == "main" ]; then
        GMP_VERSION=unstable
    fi
    docs/generate
    mkdir -p "${GEN_DIR}/protocol/${GMP_VERSION}"
    mv docs/osp.html "${GEN_DIR}/protocol/${GMP_VERSION}/"
}
dl_osp_doc main
dl_osp_doc stable
dl_osp_doc oldstable
cd "${WORK_DIR}"
rm -rf ospd-openvas

(
    cd "${WORK_DIR}/_index"
    poetry install
) || (echo "no poetry install" && exit 1)
cd "${WORK_DIR}/_index"
poetry run make html
cp -ar build/html/. "${GEN_DIR}/" || cp -ar _build/html/. "${GEN_DIR}/" || (echo "no build/html folder" && exit 1)

cd "${GEN_DIR}" || (echo "no ${GEN_DIR} found" && exit 1)
git add .
git commit -m "Update docs - Build $(date '+%Y%m%d%H%M%S')" || true
git branch --set-upstream-to=origin/gh-pages gh-pages
git push

cd "${WORK_DIR}"
git add .
git commit -m "Update docs - Build $(date '+%Y%m%d%H%M%S')" || true
git push
