c.KernelSpecManager.whitelist = {'py2', 'py3'}
c.NotebookApp.terminado_settings = {
    'shell_command': ['/bin/bash', '-l', '-i'],
}
c.InteractiveShellApp.exec_lines = ["import sys; sys.argv[1:] = []"]
