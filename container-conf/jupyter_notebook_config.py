c.KernelSpecManager.whitelist = {'py3', 'py2'}
c.NotebookApp.terminado_settings = {
    'shell_command': ['/bin/bash', '-l', '-i'],
}
# https://jupyterlab.readthedocs.io/en/stable/user/jupyterhub.html#use-jupyterlab-by-default
c.NotebookApp.nbserver_extensions.jupyterlab = True
