#!/bin/bash

# Jupyter no longer supports py2
beamsim_jupyter_py2_pip_versions=(
    SQLAlchemy==1.2.4
    alembic==0.9.8
    bleach==2.1.2
    ipykernel==4.8.2
    ipython-genutils==0.2.0
    jupyter-client==5.2.2
    jupyter-console==5.2.0
    jupyter-core==4.4.0
    jupyter==1.0.0
    nbconvert==5.3.1
    nbformat==4.4.0
    notebook==5.3.0rc1
    tornado==4.5.3
    traitlets==4.3.2
    ipython==5.5.0

    # These don't need to be version locked
    ipympl
    plotly
)

beamsim_jupyter_py3_pip_versions=(
    SQLAlchemy
    alembic
    bleach
    ipykernel
    ipython-genutils
    jupyter-client
    jupyter-console
    jupyter-core
    jupyter
    nbconvert
    nbformat
    notebook
    tornado
    traitlets
    ipython
    ipywidgets
    ipympl
    plotly
)

beamsim_jupyter_install_jupyter_venv() {
    install_not_strict_cmd pyenv shell py3
    local v=( $(python3 --version) )
    install_not_strict_cmd pyenv virtualenv "${v[1]}" "$beamsim_jupyter_jupyter_venv"
    # sets pyenv
    beamsim_jupyter_install_py3_venv "$beamsim_jupyter_jupyter_venv"
    # POSIT: versions same in container-jupyterhub/build.sh
    pip install jupyterlab==2.1.0 jupyterhub==1.1.0 jupyterlab-launcher nbzip
    # needed for ipywidgets
    jupyter nbextension enable --py widgetsnbextension --sys-prefix
    # Note: https://github.com/jupyterlab/jupyterlab/issues/5420
    # will produce a collision (but warning) on vega-lite
    jupyter labextension install --no-build \
        @jupyter-widgets/jupyterlab-manager \
        @jupyterlab/hub-extension \
        jupyter-matplotlib \
        jupyterlab-plotly \
        plotlywidget \
        jupyterlab-chart-editor
    # https://jupyterlab.readthedocs.io/en/stable/user/jupyterhub.html#use-jupyterlab-by-default
    jupyter serverextension enable --py jupyterlab --sys-prefix
    beamsim_jupyter_install_jupyter_rs_radia
    jupyter lab build
    # nbzip only works with classic jupyter
    jupyter serverextension enable --py nbzip --sys-prefix
    jupyter nbextension install --py nbzip --sys-prefix
    jupyter nbextension enable --py nbzip --sys-prefix
    install_not_strict_cmd pyenv shell --unset
}

beamsim_jupyter_install_jupyter_rs_radia() {
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

beamsim_jupyter_install_py_packages() {
    # always reinstall pykern
    pip uninstall -y pykern >& /dev/null || true
    pip install pykern
}

beamsim_jupyter_install_py3_packages() {
    local x=(
        funcsigs
        llvmlite
        numba
        # needs to be before fbpic https://github.com/radiasoft/devops/issues/153
        pyfftw
        # https://github.com/radiasoft/devops/issues/152
        fbpic

        # https://github.com/radiasoft/jupyter.radiasoft.org/issues/75
        gpflow
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/10
        GPy
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/11
        safeopt
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/13
        seaborn
        yt
        # needed by zgoubidoo
        parse
    )
    pip install "${x[@]}"
    local f
    for f in chernals/zgoubidoo radiasoft/jupyter-rs-vtk radiasoft/jupyter-rs-radia; do
        pip install "git+https://github.com/$f"
    done
    # If you need to install a particular branch:
    # pip install "git+https://github.com/radiasoft/jupyter-rs-radia@issue/30"

}

beamsim_jupyter_ipy_kernel_env() {
    # http://ipython.readthedocs.io/en/stable/install/kernel_install.html
    # http://www.alfredo.motta.name/create-isolated-jupyter-ipython-kernels-with-pyenv-and-virtualenv/
    local display_name=$1
    local name=$2
    local where=( $(python -m ipykernel install --display-name "$display_name" --name "$name" --user) )
    local x=$(ls ~/.pyenv/pyenv.d/exec/*synergia*.bash 2>/dev/null || true)
    if [[ $x ]]; then
        . "$x"
    fi
    PYENV_VERSION=$name perl -pi -e '
        sub _e {
            return join(
                qq{,\n},
                map(
                    $ENV{$_} ? qq{  "$_": "$ENV{$_}"} : (),
                    qw(SYNERGIA2DIR LD_LIBRARY_PATH PYENV_VERSION PYTHONPATH),
                ),
            );
        }
        s/^\{/{\n "env": {\n@{[_e()]}\n },/
    ' "${where[-1]}"/kernel.json
}

beamsim_jupyter_install_py3_venv() {
    local venv=$1
    install_not_strict_cmd pyenv shell "$venv"
    pip install "${beamsim_jupyter_py3_pip_versions[@]}"
}

beamsim_jupyter_reinstall() {
    # Need to uninstall jupyter/ipython, and reinstall to get the latest versions for
    # widgetsnbextension
    local f
    for f in ipython_genutils ipyparallel ipykernel ipywidgets ipython jupyter_client jupyter_core; do
        pip uninstall -y "$f" >& /dev/null || true
    done

    pip install "${beamsim_jupyter_py2_pip_versions[@]}"
    jupyter nbextension enable --py --sys-prefix widgetsnbextension
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
    build_image_base=radiasoft/beamsim
    beamsim_jupyter_boot_dir=$build_run_user_home/.radia-run
    beamsim_jupyter_radia_run_boot=$beamsim_jupyter_boot_dir/start
    build_is_public=1
    build_docker_cmd='["'"$beamsim_jupyter_radia_run_boot"'"]'
    build_dockerfile_aux="USER $build_run_user"
}

build_as_root() {
    umask 022
    local r=(
        emacs-nox
        hostname
        npm
        # Needed for MPI nodes
        openssh-server
        # For cluster start
        bind-utils
        # Needed for debugging
        iproute
        # https://github.com/radiasoft/devops/issues/188
        pandoc
        strace
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
    export beamsim_jupyter_notebook_template_dir=$beamsim_jupyter_boot_dir/$notebook_dir_base
    export beamsim_jupyter_jupyter_venv=jupyter
    export beamsim_jupyter_depot_server=$(install_depot_server)
    beamsim_jupyter_install_jupyter_venv
    mkdir -p "$beamsim_jupyter_notebook_dir" "$beamsim_jupyter_notebook_template_dir"
    local f
    for f in ~/.jupyter/jupyter_notebook_config.py ~/.ipython/profile_default/ipython_config.py; do
        mkdir -p "$(dirname "$f")"
        build_replace_vars "$(basename "$f")" "$f"
    done
    build_replace_vars radia-run.sh "$beamsim_jupyter_radia_run_boot"
    chmod a+rx "$beamsim_jupyter_radia_run_boot"
    build_replace_vars post_bivio_bashrc ~/.post_bivio_bashrc
    install_source_bashrc
    local i
    for i in 2 3; do
        local v=py$i
        if [[ $i == 3 ]]; then
            # sets pyenv
            beamsim_jupyter_install_py3_venv "$v"
            beamsim_jupyter_install_py3_packages
        else
            install_not_strict_cmd pyenv shell "$v"
            beamsim_jupyter_reinstall
        fi
        beamsim_jupyter_install_py_packages
        beamsim_jupyter_ipy_kernel_env "Python $i" "$v"
        install_not_strict_cmd pyenv shell --unset
    done
    beamsim_jupyter_rsbeams_style
    # Removes the export TERM=dumb, which is incorrect for jupyter
    rm -f ~/.pre_bivio_bashrc
}

beamsim_jupyter_vars
