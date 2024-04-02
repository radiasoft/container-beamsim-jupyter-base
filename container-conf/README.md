# Build & test

```sh
cd ~/src/radiasoft/container-beamsim-jupyter-base
radia_run container-build
docker run --rm --name=jpy -it --network=host -v $PWD/tests:/home/vagrant/jupyter radiasoft/beamsim-jupyter-base:alpha
```

Run all cells in `00-py3.ipynb`.

Interrogate container:

```sh
docker exec -it jpy bash
```
