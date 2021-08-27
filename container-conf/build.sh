#!/bin/bash

beamsim_jupyter_jupyterlab() {
    # https://github.com/jupyter/notebook/issues/2435
    # installed by rpm-code/codes/rsbeams.sh, but here to
    # document
    install_assert_pip_version jedi 0.17.2 'check codes/rsbeams.sh'
    # POSIT: versions same in container-jupyterhub/build.sh
    local x=(
        ipympl==0.5.8
        ipywidgets
        jupyter
        jupyterhub==1.1.0
        jupyterlab-launcher
        jupyterlab-server==1.2.0
        jupyterlab==2.1.0
        nbzip
        plotly

        # modules users have requested
        funcsigs
        llvmlite
        numba
        # needs to be before fbpic https://github.com/radiasoft/devops/issues/153
        pyfftw
        # https://github.com/radiasoft/devops/issues/152
        fbpic

# temporarily disable https://github.com/radiasoft/container-beamsim-jupyter/issues/40
#        # https://github.com/radiasoft/jupyter.radiasoft.org/issues/75
#        gpflow
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/10
        GPy
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/11
        safeopt
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/13
        seaborn
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/38
        torch
        torchvision
        pygmo
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/39
        botorch
        # needed by zgoubidoo
        parse

        # https://github.com/radiasoft/container-beamsim-jupyter/issues/32
        # installs bokeh, too
        git+https://github.com/slaclab/lume-genesis
        git+https://github.com/ChristopherMayes/openPMD-beamphysics
        git+https://github.com/radiasoft/zfel

        # https://github.com/radiasoft/container-beamsim-jupyter/issues/42
        bluesky
    )
    pip install "${x[@]}"
    # needed for ipywidgets
    jupyter nbextension enable --py widgetsnbextension --sys-prefix
    # Note: https://github.com/jupyterlab/jupyterlab/issues/5420
    # will produce a collision (but warning) on vega-lite
    jupyter labextension install --no-build \
        @jupyter-widgets/jupyterlab-manager@2.0.0 \
        @jupyterlab/hub-extension@2.1.0 \
        jupyter-matplotlib@0.7.4 \
        jupyterlab-plotly@4.14.1 \
        plotlywidget@4.14.1 \
        jupyterlab-chart-editor@4.10.0 \
        jupyterlab-favorites@2.0.0
    # https://jupyterlab.readthedocs.io/en/stable/user/jupyterhub.html#use-jupyterlab-by-default
    jupyter serverextension enable --py jupyterlab --sys-prefix
    beamsim_jupyter_rs_radia
    if ! jupyter lab build; then
        tail -100 /tmp/jupyterlab*.log || true
        build_err 'juptyer lab failed to build'
    fi
    # nbzip only works with classic jupyter
    jupyter serverextension enable --py nbzip --sys-prefix
    jupyter nbextension install --py nbzip --sys-prefix
    jupyter nbextension enable --py nbzip --sys-prefix
}

beamsim_jupyter_rs_radia() {
    local f m
    local p=$(pwd)
    mkdir -p ~/src/radiasoft
    cd ~/src/radiasoft
    for f in jupyter-rs-vtk jupyter-rs-radia; do
        git clone https://github.com/radiasoft/"$f"
        cd "$f"
        pip install .
        m=${f#*/}
        jupyter nbextension enable --py --sys-prefix "${m//-/_}"
        cd js
        jupyter labextension install --no-build .
        cd ../..
    done
    cd "$p"
}

beamsim_jupyter_rsbeams_style() {
    local dst
    local src
    # https://github.com/radiasoft/container-beamsim-jupyter/issues/27
    local d=~/.config/matplotlib/stylelib
    mkdir -p "$d"
    git clone https://github.com/radiasoft/rsbeams
    for src in rsbeams/rsbeams/rsplot/stylelib/*; do
        dst=$d/$(basename "$src")
        cp "$src" "$dst"
    done
    rm -rf rsbeams
}

beamsim_jupyter_vars() {
    build_image_base=radiasoft/sirepo
    beamsim_jupyter_boot_dir=$build_run_user_home/.radia-run
    beamsim_jupyter_radia_run_boot=$beamsim_jupyter_boot_dir/start
    build_is_public=1
    build_docker_cmd='["'"$beamsim_jupyter_radia_run_boot"'"]'
    build_dockerfile_aux="USER $build_run_user"
}

build_as_root() {
    umask 022
    local r=(
        rscode-ipykernel
        # Needed for MPI nodes
        openssh-server
        # https://github.com/radiasoft/devops/issues/188
        pandoc
        # https://github.com/radiasoft/devops/issues/153
        fftw3-devel
        vim-enhanced
        gnuplot-minimal
    )
    build_yum install "${r[@]}"
    # Add RPMFusion repo for ffmpeg
    # http://rpmfusion.org/Configuration
    local e=release-$(build_fedora_version).noarch.rpm
    build_yum install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-"$e"
    build_yum install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-"$e"
    build_yum install ffmpeg texlive-scheme-medium
    # https://github.com/radiasoft/container-beamsim-jupyter/issues/40
    build_yum install rscode-graphtool
    # ffmpeg installed from rpmfusion so disable it for other packages
    dnf config-manager --set-disabled 'rpmfusion*'
}

build_as_run_user() {
    # Make sure readable-executable by world in case someone wants to
    # run the container as non-vagrant user.
    umask 022
    if [[ $(pyenv version-name) != py3 ]]; then
        build_err "ASSERTION FAULT: environment is not right, missing pyenv: $(env)"
    fi
    cd "$build_guest_conf"
    beamsim_jupyter_vars
    local notebook_dir_base=jupyter
    export beamsim_jupyter_notebook_dir=$build_run_user_home/$notebook_dir_base
    export beamsim_jupyter_boot_dir
    export beamsim_jupyter_notebook_bashrc=$notebook_dir_base/bashrc
    export beamsim_jupyter_depot_server=$(install_depot_server)
    beamsim_jupyter_jupyterlab
    beamsim_jupyter_rsbeams_style
    mkdir -p "$beamsim_jupyter_notebook_dir"
    local f
    for f in ~/.jupyter/jupyter_notebook_config.py ~/.ipython/profile_default/ipython_config.py; do
        mkdir -p "$(dirname "$f")"
        build_replace_vars "$(basename "$f")" "$f"
    done
    build_replace_vars radia-run.sh "$beamsim_jupyter_radia_run_boot"
    chmod a+rx "$beamsim_jupyter_radia_run_boot"
    build_replace_vars post_bivio_bashrc ~/.post_bivio_bashrc
    install_source_bashrc
    # Removes the export TERM=dumb, which is incorrect for jupyter
    rm -f ~/.pre_bivio_bashrc
}

beamsim_jupyter_vars
