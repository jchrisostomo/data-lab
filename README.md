# data-lab

[![Licença: MIT](https://img.shields.io/badge/licen%C3%A7a-MIT-blue.svg)](LICENSE)

Laboratório para estudar e praticar engenharia, análise e ciência de dados. O repositório sobe uma AWS local, com o emulador [Floci](https://github.com/floci-io/floci), usando um único comando. Não precisa de conta na AWS e não tem custo.

Clone em qualquer pasta, rode `make build` e você terá S3, SQS, DynamoDB e outros serviços respondendo em `http://localhost:4566`.

**Neste README:** [Começar](#começar) · [Comandos](#comandos) · [Como funciona](#como-funciona) · [Problemas comuns](#problemas-comuns) · [Próximos passos](#próximos-passos)

## O que você ganha

- **AWS local em Docker**, com os dados guardados em disco. Parar e subir de novo não apaga nada.
- **Comandos curtos** para o dia a dia: `make up`, `make down`, `make status`.
- **Dois testes prontos**: um confere o S3 e outro confere se os dados sobrevivem a uma reinicialização.
- **AWS CLI isolada**: o repositório traz a própria configuração e não mexe no seu `~/.aws/config`.
- **Sem caminho fixo**: funciona em qualquer pasta.

## Requisitos

| Ferramenta | Para quê |
| --- | --- |
| Docker, com o daemon ativo | Roda o Floci |
| `make` | Executa os comandos do projeto |
| [`uv`](https://docs.astral.sh/uv/) | Gerencia o ambiente Python |
| `curl` | Confere se o Floci está respondendo |
| AWS CLI | Conversa com o Floci |

> [!NOTE]
> Testado em Windows com WSL. Em Linux e macOS deve funcionar do mesmo jeito, mas ainda não foi testado. No Windows, use um terminal do WSL e ative a integração do Docker Desktop com a sua distribuição. O PowerShell puro não é suportado, porque o Makefile usa bash.

## Começar

**1. Clone o repositório**

```bash
git clone git@github.com:jchrisostomo/data-lab.git
cd data-lab
```

**2. Prepare e suba o ambiente**

```bash
make build
```

Na primeira vez, o `make build` confere o Docker, cria o `.env`, instala as dependências Python, baixa a imagem do Floci e sobe o container. Ele só termina quando o Floci está respondendo.

**3. Configure o terminal**

```bash
eval "$(make -s env)"
```

Isso carrega o endereço do Floci, as credenciais de mentira e a configuração da AWS CLI. Vale só para o terminal em que você rodou, então repita em terminais novos.

**4. Experimente**

```bash
aws s3 mb s3://meu-bucket
aws s3 ls
```

**5. Rode os testes**

```bash
make test
make test-persist
```

Cada um imprime uma linha começando com `OK` quando passa.

## Comandos

Rode `make help` para ver a lista completa.

| Comando | O que faz |
| --- | --- |
| `make build` | Primeira vez: prepara tudo e sobe o Floci |
| `make sync` | Instala as dependências Python |
| `make up` | Sobe o Floci e espera ele ficar saudável |
| `make down` | Para o Floci e mantém os dados |
| `make restart` | Reinicia o Floci |
| `make logs` | Acompanha os logs |
| `make status` | Mostra o estado do container e do endpoint |
| `make doctor` | Diagnóstico do ambiente |
| `make env` | Imprime as variáveis de ambiente, para usar com `eval` |
| `make test` | Cria um bucket, envia um arquivo, baixa e compara |
| `make test-persist` | Grava um dado, reinicia o Floci e confere se ele continua |
| `make clean` | Remove o container e apaga os dados |

> [!WARNING]
> O `make clean` apaga o volume com todos os dados do Floci. Para só parar o ambiente, use `make down`.

## Como funciona

### Estrutura

```
data-lab/
├── Makefile             comandos do projeto, comentados para estudo
├── docker-compose.yml   container do Floci e volume de dados
├── aws/config           configuração da AWS CLI usada só neste repositório
├── .env.example         variáveis de ambiente (vira o .env no build)
├── pyproject.toml       projeto Python gerenciado pelo uv
└── src/data_lab/        código Python
```

### Decisões de projeto

| Tema | Como está resolvido |
| --- | --- |
| Persistência | O Floci roda em modo `persistent` e grava no volume Docker `floci-data`. O `make down` mantém o volume. |
| AWS CLI | O Makefile aponta `AWS_CONFIG_FILE` para `aws/config`, que força o S3 em path-style, o que o Floci espera. |
| Caminhos | O caminho do `aws/config` é calculado a cada execução. O repositório pode ficar em qualquer pasta e até ser movido depois. |
| Credenciais | O `.env` usa credenciais de mentira (`test`). O Floci não valida nada. Nunca coloque credenciais reais ali. |

## Problemas comuns

| Sintoma | O que fazer |
| --- | --- |
| `Docker não encontrado` ou `Daemon do Docker inacessível` | Inicie o Docker. No WSL, ative a integração do Docker Desktop com a sua distribuição, em Settings, Resources, WSL integration. |
| `port is already allocated`, porta 4566 em uso | Outro container usa a porta. Veja qual com `docker ps` e pare com `docker stop <nome>`. |
| `'str' object has no attribute 'get'` na AWS CLI | Quase sempre é um `~/.aws/config` com uma configuração aninhada escrita em uma linha só. Rode `eval "$(make -s env)"`, e a AWS CLI passa a usar o `aws/config` do repositório no lugar do global. |
| Os buckets sumiram | Se você rodou `make clean`, o volume foi apagado, e isso é esperado. Fora isso, confira com `make test-persist`. |
| Movi ou renomeei a pasta | Não precisa mudar nada no projeto. Rode o `eval "$(make -s env)"` de novo no terminal. |

## Próximos passos

Este repositório é a base de um laboratório que vai crescer. Entre as ideias planejadas estão um data lake de transações Pix e um data warehouse com dbt. A versão atual cobre apenas o ambiente local.

## Licença

[MIT](LICENSE)
