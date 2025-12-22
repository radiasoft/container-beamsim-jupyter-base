#!/bin/bash

beamsim_jupyter_base_jupyterlab() {
    # POSIT: versions same in container-jupyterhub/build.sh
    declare x=(
        ipympl==0.9.6
        ipywidgets==7.6.5
        jupyter==1.0.0
        jupyter-packaging==0.10.6
        git+https://github.com/radiasoft/jupyter-tensorboard-proxy.git
        jupyterhub==1.4.2
        jupyterlab-launcher==0.13.1
        jupyterlab-server==2.8.2
        jupyterlab==3.1.14
        plotly
        jupyterlab-favorites==3.0.0
        jupyterlab-widgets==1.0.2

        # https://github.com/radiasoft/container-beamsim-jupyter-base/issues/117
        jupyterlab-h5web
    )
    pip install "${x[@]}"
    julia -e 'using Pkg; Pkg.add("IJulia")'

    declare n
    install_pip_install pygmo
    n=--openssl-legacy-provider
    declare l=(
        @jupyterlab/server-proxy
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

beamsim_jupyter_base_lab() {
    declare f
    declare p=$(pwd)
    mkdir -p ~/src/radiasoft
    for f in jupyter_rs_vtk jupyter_rs_radia; do
        cd ~/src/radiasoft
        git clone https://github.com/radiasoft/"$f"
        cd "$f"
        pip install .
        cd js
        jupyter labextension install --no-build .
    done
    cd "$p"
}

beamsim_jupyter_base_rsbeams_style() {
    declare dst
    declare src
    # https://github.com/radiasoft/container-beamsim-jupyter-base/issues/27
    declare d=~/.config/matplotlib/stylelib
    mkdir -p "$d"
    git clone https://github.com/radiasoft/rsbeams
    for src in rsbeams/rsbeams/rsplot/stylelib/*; do
        dst=$d/$(basename "$src")
        cp "$src" "$dst"
    done
    rm -rf rsbeams
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
        # https://github.com/radiasoft/devops/issues/188
        pandoc
        # https://github.com/radiasoft/devops/issues/153
        fftw3-devel
        vim-enhanced
        gnuplot-minimal
        ncl-devel
        rscode-geant4
        rscode-julia
        rscode-madness
        rscode-genesis4
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
