#!/bin/bash
#
# Start juypterhub's single user init script with appropriate environment
# for radiasoft/beamsim.
#
cd
. "$HOME"/.bashrc
pyenv activate '{beamsim_jupyter_jupyter_venv}'
u=${JUPYTERHUB_USER:-${JPY_USER:-}}
curl https://depot.radiasoft.org/index.sh \
    | bash -s init-from-git radiasoft/jupyter.radiasoft.org \
        ${u:+"$u"/jupyter.radiasoft.org}
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
      --KernelManager.transport=ipc \
      --notebook-dir="$PWD"
    # Note that type -f is not executable, because of the way pyenv finds programs so
    # this is only for error messages.
    RADIA_RUN_CMD=$(type -f jupyter-labhub)
elif [[ ${JPY_USER:-} ]]; then
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
      --notebook-dir="$PWD"
    RADIA_RUN_CMD=$(type -f jupyterhub-singleuser)
else
    # Start jupyter lab possibly with radia-run supplied token
    # urandom never blocks and is good enough for this case
    p="${RADIA_RUN_PORT:-8888}"
    RADIA_RUN_CMD="jupyter lab --no-browser --port=$p --ip=0.0.0.0"
    #POSIT download/installers/container-run/radiasoft-download.sh
    t=$(cat .radia-run-jupyter-token 2>/dev/null || true)
    rm -f .radia-run-jupyter-token
    if [[ $t ]]; then
        echo "c.NotebookApp.token = '$t'" >> $HOME/.jupyter/jupyter_notebook_config.py
        cat <<EOF
To connect to Jupyter, open:

http://127.0.0.1:$p/?token=$t

EOF
    fi
    exec $RADIA_RUN_CMD
fi
echo "ERROR: '$RADIA_RUN_CMD': exec failed'" 1>&2
exit 1
