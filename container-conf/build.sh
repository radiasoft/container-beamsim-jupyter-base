#!/bin/bash

beamsim_jupyter_base_jupyterlab() {
    # POSIT: versions same in container-jupyterhub/build.sh
    declare x=(
        # These lists were created by pip installing packages and seeing which versions were installed.
        # The "Successfully installed" line which pip outputs

        # pip install jupyterlab
        'jupyterlab==4.5.1'
        'argon2-cffi==25.1.0'
        'argon2-cffi-bindings==25.1.0'
        'arrow==1.4.0'
        'async-lru==2.0.5'
        'beautifulsoup4==4.14.3'
        'bleach==6.3.0'
        'defusedxml==0.7.1'
        'fastjsonschema==2.21.2'
        'fqdn==1.5.1'
        'isoduration==20.11.0'
        'json5==0.12.1'
        'jsonpointer==3.0.0'
        'jupyter-events==0.12.0'
        'jupyter-lsp==2.3.0'
        'jupyter-server==2.17.0'
        'jupyter-server-terminals==0.5.3'
        'jupyterlab-pygments==0.3.0'
        'jupyterlab-server==2.28.0'
        'mistune==3.1.4'
        'nbclient==0.10.3'
        'nbconvert==7.16.6'
        'nbformat==5.10.4'
        'notebook-shim==0.2.4'
        'pandocfilters==1.5.1'
        'prometheus-client==0.23.1'
        'python-json-logger==4.0.0'
        'rfc3339-validator==0.1.4'
        'rfc3986-validator==0.1.1'
        'rfc3987-syntax==1.1.0'
        'send2trash==1.8.3'
        'soupsieve==2.8.1'
        'terminado==0.18.1'
        'tinycss2==1.4.0'
        'uri-template==1.3.0'
        'webcolors==25.10.0'
        'webencodings==0.5.1'
        'websocket-client==1.9.0'

        # pip install ipympl
        'ipympl==0.9.8'
        'ipywidgets==8.1.8'
        'jupyterlab_widgets==3.0.16'
        'widgetsnbextension==4.0.15'

        # pip install jupyter
        'jupyter==1.1.1'
        'jupyter-console==6.6.3'
        'notebook==7.5.1'

        # pip install jupyter-packaging
        'jupyter-packaging==0.12.3'
        'deprecation==2.1.0'
        'tomlkit==0.13.3'

        # Individual packages (not depending on each other)
        'jupyterlab-launcher==0.13.1'
        'jupyterlab-favorites==3.3.1'
        'plotly==6.5.0'

        # https://github.com/radiasoft/container-beamsim-jupyter-base/issues/118
        'numba==0.63.1'
        'llvmlite==0.46.0'

        # jupyterhub
        'jupyterhub==5.4.3'
        'Mako==1.3.10'
        'alembic==1.17.2'
        'certipy==0.2.2'
        'oauthlib==3.3.1'
        'pamela==1.2.0'

        # https://github.com/radiasoft/container-beamsim-jupyter-base/issues/117
        # pip install jupyterlab-h5web
        'jupyterlab-h5web==12.6.1'
        'h5grove==2.3.0'
        'orjson==3.11.5'
    )
    pip install "${x[@]}"
    julia -e 'using Pkg; Pkg.add("IJulia")'
    declare l=(
        # Note: https://github.com/jupyterlab/jupyterlab/issues/5420
        # will produce a collision (but warning) on vega-lite
        jupyterlab-chart-editor@4.14.3
    )
    jupyter labextension install --no-build "${l[@]}"
    # https://jupyterlab.readthedocs.io/en/stable/user/jupyterhub.html#use-jupyterlab-by-default
    beamsim_jupyter_base_lab
    # Need dev-build because jupyter lab build defaults to dev build
    # when there are declare extensions (jupyter-rs-*)
    # See https://git.radiasoft.org/radiasoft/container-beamsim-jupyter-base/issues/81 for reason behind NODE_OPTIONS
    if ! NODE_OPTIONS="$n" jupyter lab build --dev-build=False; then
        tail -100 /tmp/jupyterlab*.log || true
        build_err 'juptyer lab failed to build'
    fi
}

beamsim_jupyter_base_rs_widgets() {
    declare f
    declare p=$(pwd)
    for f in jupyter_rs_vtk jupyter_rs_radia; do
        codes_download radiasoft/"$f"
        pip install .
        cd js
        jupyter labextension install --no-build .
        cd "$p"
    done
}

beamsim_jupyter_base_rsbeams_style() {
    declare dst
    declare src
    # https://github.com/radiasoft/container-beamsim-jupyter-base/issues/27
    declare d=~/.config/matplotlib/stylelib
    mkdir -p "$d"
    codes_download radiasoft/rsbeams
    for src in rsbeams/rsplot/stylelib/*; do
        cp "$src" "$d/$(basename "$src")"
    done
    cd ..
}

beamsim_jupyter_base_vars() {
    build_image_base=radiasoft/beamsim
    beamsim_jupyter_base_boot_dir=$build_run_user_home/.radia-run
    beamsim_jupyter_base_radia_run_boot=$beamsim_jupyter_base_boot_dir/start
    build_is_public=1
    build_docker_cmd='["'"$beamsim_jupyter_base_radia_run_boot"'"]'
}

build_as_root() {
    umask 022
    declare r=(
        rscode-ipykernel
        # Needed to export notebooks https://github.com/radiasoft/devops/issues/188
        pandoc
        vim-enhanced
        gnuplot-minimal
        ncl-devel

        # Keep up to date with download/installers/beamsim-codes
        rscode-geant4
        rscode-julia
        rscode-madness

        # USPAS (temporary?) https://github.com/radiasoft/container-beamsim-jupyter-base/issues/117
        mc
    )

    build_yum install "${r[@]}"
    # Add RPMFusion repo for ffmpeg
    # http://rpmfusion.org/Configuration
    declare e=release-$(build_fedora_version).noarch.rpm
    build_yum install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-"$e"
    build_yum install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-"$e"
    build_yum install ffmpeg texlive-scheme-medium texlive-collection-latexextra
    # ffmpeg installed from rpmfusion so disable it for other packages
    install_yum_repo_set_enabled 'rpmfusion*' 0
}

build_as_run_user() {
    # Make sure readable-executable by world in case someone wants to
    # run the container as non-vagrant user.
    umask 022
    if [[ $(pyenv version-name) != py3 ]]; then
        build_err "ASSERTION FAULT: environment is not right, missing pyenv: $(env)"
    fi
    cd "$build_guest_conf"
    beamsim_jupyter_base_vars
    declare notebook_dir_base=jupyter
    export beamsim_jupyter_base_notebook_dir=$build_run_user_home/$notebook_dir_base
    export beamsim_jupyter_base_boot_dir
    export beamsim_jupyter_base_notebook_bashrc=$notebook_dir_base/bashrc
    export beamsim_jupyter_base_depot_server=$(install_depot_server)
    beamsim_jupyter_base_jupyterlab
    beamsim_jupyter_base_rsbeams_style
    mkdir -p "$beamsim_jupyter_base_notebook_dir"
    declare j=jupyter_server_config.py
    python - <<'EOF' >> "$j"
from pykern import pkio
d = pkio.py_path("~/.local/share/jupyter/kernels/*/kernel.json")
s = set(x.dirpath().basename for x in pkio.sorted_glob(d))
assert s, f"could not find any kernels in dir={d}"
print(f"c.KernelSpecManager.allowed_kernelspecs = {s}\n")
EOF
    declare f
    for f in ~/.jupyter/"$j" ~/.ipython/profile_default/ipython_config.py; do
        mkdir -p "$(dirname "$f")"
        build_replace_vars "$(basename "$f")" "$f"
    done
    mkdir -p "$(dirname "$beamsim_jupyter_base_radia_run_boot")"
    build_replace_vars radia-run.sh "$beamsim_jupyter_base_radia_run_boot"
    chmod a+rx "$beamsim_jupyter_base_radia_run_boot"
    build_replace_vars post_bivio_bashrc ~/.post_bivio_bashrc
    install_source_bashrc
    # Removes the export TERM=dumb, which is incorrect for jupyter
    rm -f ~/.pre_bivio_bashrc
}

beamsim_jupyter_base_vars
