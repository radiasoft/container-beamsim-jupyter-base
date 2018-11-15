#!/bin/bash
#
# Start juypterhub's single user init script with appropriate environment
# for radiasoft/beamsim.
#
cd
. "$HOME"/.bashrc
curl radia.run | bash -s init-from-git radiasoft/jupyter.radiasoft.org \
    "${JUPYTERHUB_USER:-$JPY_USER}"/jupyter.radiasoft.org
pyenv activate '{beamsim_jupyter_jupyter_venv}'
# must be after to avoid false returns in bashrc, init-from-git, and pyenv
set -e
cd '{beamsim_jupyter_notebook_dir}'
if [[ ${RADIA_RUN_CMD:-} ]]; then
    # Can't quote this, because environment var, not a bash array
    exec $RADIA_RUN_CMD
elif [[ ${JUPYTERHUB_API_URL:-} ]]; then
    # jupyterhub 0.9+
    # https://github.com/jupyter/docker-stacks/tree/master/base-notebook for
    # why this is started this way.
    # POSIT: 8888 in various jupyterhub repos
    exec jupyter-labhub \
      --port="${RADIA_RUN_PORT:-8888}" \
      --ip=0.0.0.0 \
      --notebook-dir='{beamsim_jupyter_notebook_dir}'
    # Note that type -f is not executable, because of the way pyenv finds programs so
    # this is only for error messages.
    RADIA_RUN_CMD=$(type -f jupyter-labhub)
else
    # "legacy" jupyterhub pre-0.8
    # POSIT: 8888 in various jupyterhub repos
    exec jupyterhub-singleuser \
      --port="${RADIA_RUN_PORT:-8888}" \
      --ip=0.0.0.0 \
      --user="$JPY_USER" \
      --cookie-name="$JPY_COOKIE_NAME" \
      --base-url="$JPY_BASE_URL" \
      --hub-prefix="$JPY_HUB_PREFIX" \
      --hub-api-url="$JPY_HUB_API_URL" \
      --notebook-dir='{beamsim_jupyter_notebook_dir}'
    RADIA_RUN_CMD=$(type -f jupyterhub-singleuser)
fi
echo "ERROR: '$RADIA_RUN_CMD': exec failed'" 1>&2
exit 1
