#!/bin/bash

beamsim_jupyter_py2_versions=(
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
)

beamsim_jupyter_jupyter_versions=(
    "${beamsim_jupyter_py2_versions[@]}"
    ipython==6.2.1
    ipywidgets==7.1.0
    jupyterhub==0.8.1
    jupyterlab-launcher==0.10.2
    jupyterlab==0.31.0
)

beamsim_jupyter_py2_versions+=(
    ipython==5.5.0
)

beamsim_jupyter_extra_packages() {
    # https://github.com/radiasoft/devops/issues/153
    build_yum install fftw3-devel
    local x=(
        # https://github.com/radiasoft/devops/issues/153
        # needs to be before fbpic
        pyfftw
        # https://github.com/radiasoft/devops/issues/152
        fbpic
        # https://github.com/radiasoft/devops/issues/135
        sklearn keras tensorflow
        # https://github.com/radiasoft/devops/issues/146
        pillow
    )
    pip install "${x[@]}"
}

beamsim_jupyter_install_jupyter() {
    pyenv update || true
    local pyver=3.5.2
    # https://github.com/pyenv/pyenv/issues/950#issuecomment-334316289
    # need older openssl version (1.0.x)
    build_yum remove openssl-devel; build_yum install compat-openssl10-devel
    pyenv install "$pyver"
    pyenv virtualenv "$pyver" "$beamsim_jupyter_jupyter_venv"
    pyenv activate "$beamsim_jupyter_jupyter_venv"
    pip install --upgrade pip
    pip install --upgrade setuptools==38.4.0 tox
    pip install "${beamsim_jupyter_jupyter_versions[@]}"
    jupyter serverextension enable --py jupyterlab --sys-prefix
    jupyter nbextension enable --py --sys-prefix widgetsnbextension
}

beamsim_jupyter_ipy_kernel_env() {
    # http://ipython.readthedocs.io/en/stable/install/kernel_install.html
    # http://www.alfredo.motta.name/create-isolated-jupyter-ipython-kernels-with-pyenv-and-virtualenv/
    local display_name=$1
    local name=$2
    local where=( $(python -m ipykernel install --display-name "$display_name" --name "$name" --user) )
    . ~/.pyenv/pyenv.d/exec/*synergia*.bash
    perl -pi -e '
        sub _e {
            return join(
                qq{,\n},
                map(
                    qq{  "$_": "$ENV{$_}"},
                    qw(SYNERGIA2DIR LD_LIBRARY_PATH PYTHONPATH)));
        }
        s/^\{/{\n "env": {\n@{[_e()]}\n },/
    ' "${where[-1]}"/kernel.json
}

beamsim_jupyter_reinstall() {
    # Need to uninstall jupyter/ipython, and reinstall to get the latest versions for
    # widgetsnbextension
    local f
    for f in ipython_genutils ipyparallel ipykernel ipywidgets ipython jupyter_client jupyter_core; do
        pip uninstall -y "$f" >& /dev/null || true
    done

    pip install "${beamsim_jupyter_py2_versions[@]}"
    jupyter nbextension enable --py --sys-prefix widgetsnbextension
}

beamsim_jupyter_rsbeams_style() {
    local dst
    local src
    git clone https://github.com/radiasoft/rsbeams
    for src in rsbeams/rsbeams/rsplot/stylelib/*; do
        dst=~/.config/matplotlib/$(basename "$src")
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
    # Add RPMFusion repo:
    # http://rpmfusion.org/Configuration
    build_yum install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-27.noarch.rpm
    build_yum install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-27.noarch.rpm
    # ffmpeg for matplotlib animations
    # yum-utils for yum repo management
    build_yum install ffmpeg texlive-scheme-medium
    # ffmpeg was already installed from rpmfusion, disable it for future packages
    dnf config-manager --set-disabled 'rpmfusion*'
}

build_as_run_user() {
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
    chmod +x "$beamsim_jupyter_radia_run_boot"
    # Replace with --init??
    build_curl https://github.com/krallin/tini/releases/download/v0.16.1/tini > "$beamsim_jupyter_tini_file"
    chmod +x "$beamsim_jupyter_tini_file"
    build_replace_vars post_bivio_bashrc ~/.post_bivio_bashrc
    . ~/.bashrc

    ipython profile create default
    cat > ~/.ipython/profile_default/ipython_config.py <<'EOF'
c.InteractiveShellApp.exec_lines = ["import sys; sys.argv[1:] = []"]
EOF
    beamsim_jupyter_ipy_kernel_env 'Python 2' "$(pyenv global)"
    beamsim_jupyter_extra_packages
    beamsim_jupyter_rsbeams_style
    # Removes the export TERM=dumb, which is incorrect for jupyter
    rm -f ~/.pre_bivio_bashrc
}

beamsim_jupyter_vars
