#!/bin/bash
#
# Start juypterhub's single user init script with appropriate environment
# for radiasoft/beamsim.
#
cd
. ~/.bashrc

# must be after to avoid false returns in bashrc
set -e

curl radia.run | bash -s init-from-git radiasoft/jupyter.radiasoft.org "$JPY_USER/jupyter.radiasoft.org"

pyenv activate '{beamsim_jupyter_jupyter_venv}'

cd '{beamsim_jupyter_notebook_dir}'

if [[ $RADIA_RUN_CMD ]]; then
    # Can't quote this
    exec $RADIA_RUN_CMD
elif [[ $JUPYTERHUB_API_URL ]]; then
    # modern jupyterhub
    # https://github.com/jupyter/docker-stacks/tree/master/base-notebook for
    # why this is started this way.
    # POSIT: 8888 in various jupyterhub repos
    exec jupyterhub-singleuser \
      --port="${RADIA_RUN_PORT:-8888}" \
      --ip=0.0.0.0 \
      --notebook-dir='{beamsim_jupyter_notebook_dir}'
    RADIA_RUN_CMD=$(type -f jupyterhub-singleuser)
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
