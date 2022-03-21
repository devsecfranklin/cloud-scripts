# cloud-tools

## Usage

```sh
make python
#. _build/bin/activate.fish for FISH shell
. _build/bin/activate # for BASH
```

## container

```sh
 docker build --progress=plain -t franklin:test .
```

## dev env (for maintainers)

```sh
./bootstrap.sh
./configure
make python
```
