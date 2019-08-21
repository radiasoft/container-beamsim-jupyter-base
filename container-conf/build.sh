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

    # Doesn't appear to be version locked
    ipympl
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
    jupyterhub
    jupyterlab==1.0.6
    jupyterlab-launcher
)

beamsim_jupyter_extra_packages() {
    # https://github.com/numba/numba/issues/3341
    # need first b/c these wheels work, but --no-binary :all: turns off binary:
    # lvm-config failed executing, please point LLVM_CONFIG
    pip install funcsigs llvmlite
    # https://github.com/radiasoft/jupyter.radiasoft.org/issues/25
    pip install numba==0.41.0 --no-binary :all:
    local x=(
        # https://github.com/radiasoft/devops/issues/153
        # needs to be before fbpic
        pyfftw
        # https://github.com/radiasoft/devops/issues/152
        fbpic
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/10
        GPy
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/11
        safeopt
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/13
        seaborn
        # https://github.com/radiasoft/devops/issues/135
        scikit-learn==0.20
        keras
        tensorflow
        # https://github.com/radiasoft/container-beamsim-jupyter/issues/13
        pandas
        # https://github.com/radiasoft/devops/issues/146
        pillow
        yt
    )
    pip install "${x[@]}"
    if [[ $(pyenv version-name) == py3 ]]; then
        # https://github.com/radiasoft/jupyter.radiasoft.org/issues/46
        pip install parse
        pip install 'git+git://github.com/chernals/zgoubidoo#egg=zgoubidoo'
    fi
}

beamsim_jupyter_install_jupyter() {
    install_not_strict_cmd pyenv activate py3
    local v=( $(python3 --version) )
    install_not_strict_cmd pyenv virtualenv "${v[1]}" "$beamsim_jupyter_jupyter_venv"
    beamsim_jupyter_install_py3_venv "$beamsim_jupyter_jupyter_venv"
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
    perl -pi -e '
        sub _e {
            return join(
                qq{,\n},
                map(
                    $ENV{$_} ? qq{  "$_": "$ENV{$_}"} : (),
                    qw(SYNERGIA2DIR LD_LIBRARY_PATH PYTHONPATH),
                ),
            );
        }
        s/^\{/{\n "env": {\n@{[_e()]}\n },/
    ' "${where[-1]}"/kernel.json
}

beamsim_jupyter_install_py3_venv() {
    local venv=$1
    install_not_strict_cmd pyenv activate "$venv"
    pip install "${beamsim_jupyter_py3_pip_versions[@]}"
    jupyter serverextension enable --py jupyterlab --sys-prefix
    jupyter nbextension enable --py widgetsnbextension --sys-prefix
    # Note: https://github.com/jupyterlab/jupyterlab/issues/5420
    # will produce a collision (but warning) on vega-lite
    jupyter labextension install \
        @jupyter-widgets/jupyterlab-manager \
        @jupyterlab/hub-extension
    # https://github.com/matplotlib/jupyter-matplotlib#installation
    pip install ipympl
    # https://github.com/radiasoft/container-beamsim-jupyter/issues/12
    pip install openPMD-viewer
    jupyter labextension install jupyter-matplotlib
    pip install nbzip
    jupyter serverextension enable --py nbzip --sys-prefix
    jupyter nbextension install --py nbzip --sys-prefix
    jupyter nbextension enable --py nbzip --sys-prefix

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
    local d=~/.config/matplotlib
    mkdir -p "$d"
    git clone https://github.com/radiasoft/rsbeams
    for src in rsbeams/rsbeams/rsplot/stylelib/*; do
        dst=$d/$(basename "$src")
        cp -a "$src" "$dst"
    done
    rm -rf rsbeams
}

beamsim_jupyter_vars() {
    build_image_base=radiasoft/beamsim
    beamsim_jupyter_boot_dir=$build_run_user_home/.radia-run
    beamsim_jupyter_tini_file=$beamsim_jupyter_boot_dir/tini
    beamsim_jupyter_radia_run_boot=$beamsim_jupyter_boot_dir/start
    build_is_public=1
    build_docker_cmd='["'"$beamsim_jupyter_tini_file"'", "--", "'"$beamsim_jupyter_radia_run_boot"'"]'
    build_dockerfile_aux="USER $build_run_user"
}

build_as_root() {
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
    install_not_strict_cmd pyenv activate py2
    if [[ $(pyenv version-name) != py2 ]]; then
        build_err "ASSERTION FAULT: environment is not right, missing pyenv: $(env)"
    fi
    beamsim_jupyter_reinstall
    cd "$build_guest_conf"
    beamsim_jupyter_vars
    local notebook_dir_base=jupyter
    export beamsim_jupyter_notebook_dir=$build_run_user_home/$notebook_dir_base
    export beamsim_jupyter_boot_dir
    export beamsim_jupyter_notebook_bashrc=$notebook_dir_base/bashrc
    export beamsim_jupyter_notebook_template_dir=$beamsim_jupyter_boot_dir/$notebook_dir_base
    export beamsim_jupyter_jupyter_venv=jupyter
    (beamsim_jupyter_install_jupyter)
    mkdir -p ~/.jupyter "$beamsim_jupyter_notebook_dir" "$beamsim_jupyter_notebook_template_dir"
    build_replace_vars jupyter_notebook_config.py ~/.jupyter/jupyter_notebook_config.py
    build_replace_vars radia-run.sh "$beamsim_jupyter_radia_run_boot"
    chmod a+rx "$beamsim_jupyter_radia_run_boot"
    build_curl https://github.com/krallin/tini/releases/download/v0.16.1/tini > "$beamsim_jupyter_tini_file"
    chmod a+rx "$beamsim_jupyter_tini_file"
    build_replace_vars post_bivio_bashrc ~/.post_bivio_bashrc
    install_source_bashrc
    local i
    for i in 2 3; do
        (
            local v=py$i
            if [[ $i == 3 ]]; then
                beamsim_jupyter_install_py3_venv "$v"
            else
                install_not_strict_cmd pyenv activate "$v"
            fi
            beamsim_jupyter_extra_packages
            beamsim_jupyter_ipy_kernel_env "Python $i" "$v"
        )
    done
    beamsim_jupyter_rsbeams_style
    # Removes the export TERM=dumb, which is incorrect for jupyter
    rm -f ~/.pre_bivio_bashrc
    install_not_strict_cmd pyenv global py3:py2
}

beamsim_jupyter_vars
