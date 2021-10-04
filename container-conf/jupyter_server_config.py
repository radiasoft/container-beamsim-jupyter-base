c.KernelSpecManager.allowed_kernelspecs = {'py3', 'py2'}
c.ServerApp.terminado_settings = {
    'shell_command': ['/bin/bash', '-l', '-i'],
}

# https://jupyterlab.readthedocs.io/en/stable/user/jupyterhub.html#use-jupyterlab-by-default
c.Spawner.cmd=["jupyter-labhub"]
