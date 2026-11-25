# data-lab

Laboratório para engenharia, análise e ciência de dados, com AWS local (Floci) via Docker.

## Requisitos
Docker (daemon ativo), `make`, `uv`, `curl`.

## Uso
```bash
git clone <repo> && cd data-lab
make build          # prepara .env, dependências, baixa a imagem e sobe o Floci
source .env         # exporta endpoint e credenciais fake
aws s3 mb s3://teste
```
`make help` lista os demais comandos (up, down, status, doctor, logs, clean).

Se já existir um container `floci` antigo (criado por `floci start`) ocupando a porta 4566, rode `make legacy-clean` antes.
