# =============================================================================
# Makefile do data-lab
#
# Sobe um "mini AWS" local (Floci) com Docker e traz alguns atalhos para
# trabalhar com ele. Se estiver perdido, comece por `make help`.
#
# Como ler este arquivo:
#   alvo: dependências      <- "para fazer o alvo, faça antes as dependências"
#   <TAB>comando             <- o que roda (SEMPRE com TAB, nunca com espaços)
# =============================================================================


# ---- Configuração -----------------------------------------------------------

# Por padrão o make usa o sh. Preferi o bash porque uso `seq`, `$$(...)` e
# outras coisas que o bash trata melhor.
SHELL := /bin/bash

# Quem digita só `make` cai no help, em vez de executar algo sem querer.
.DEFAULT_GOAL := help

# Variáveis para não repetir texto. Uso: $(COMPOSE)
# (:= calcula o valor na hora; é a forma mais previsível de usar)
COMPOSE := docker compose
HEALTH_URL := http://localhost:4566/_floci/health

# Carrega o .env no shell da receita:
#   set -a  -> toda variável criada daqui pra frente é exportada
#   . ./.env -> lê o arquivo (o ponto é o mesmo que `source`)
#   set +a  -> desliga o set -a
# Assim o `aws` enxerga endpoint, credenciais e AWS_CONFIG_FILE.
LOAD_ENV := set -a; . ./.env; set +a

# Faz a AWS CLI usar o aws/config deste repo no lugar do ~/.aws/config global.
# O caminho vem de $(CURDIR) (a pasta onde o make foi chamado) e é calculado
# a cada execução. Ele NÃO é gravado em arquivo nenhum, e por isso o repo
# funciona em qualquer pasta, mesmo se você mover ou renomear a pasta depois.
# O `export` entrega a variável a todos os comandos das receitas.
export AWS_CONFIG_FILE := $(CURDIR)/aws/config

# Alvos que são ações, e não arquivos. Sem isso, se existisse um arquivo
# chamado "test" ou "up" na pasta, o make acharia que já está tudo pronto
# e não rodaria nada.
.PHONY: help build check-docker sync up down restart logs status doctor env test test-persist clean


# ---- Ajuda ------------------------------------------------------------------

# Este alvo lê o próprio Makefile e lista todo alvo que tem "## descrição".
# Por isso a documentação fica do lado do comando: ao criar um alvo novo,
# basta escrever o ## na linha dele.
#
# Passo a passo:
#   grep -E '^[a-zA-Z_-]+:.*?## '
#       pega só as linhas que começam com um nome de alvo (letras, _ ou -),
#       seguido de ":", e que tenham "## " em algum ponto depois.
#   awk 'BEGIN{FS=":.*?## "} ...'
#       corta cada linha nesse separador: o campo 1 vira o nome do alvo
#       e o campo 2, a descrição.
#   printf "  make %-14s %s\n"
#       escreve em colunas; o %-14s reserva 14 caracteres para o nome.
#   $$1 e $$2 levam dois $ porque o make consome um deles.
help: ## Lista os comandos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  make %-14s %s\n",$$1,$$2}'


# ---- Primeira vez: preparar o ambiente --------------------------------------

# O build só junta os passos: as dependências rodam na ordem em que aparecem
# (check-docker, depois .env, depois sync) e só então vem o corpo.
# Se uma delas falhar, o resto nem começa.
build: check-docker .env sync ## Primeira vez: prepara tudo e sobe o Floci
	$(COMPOSE) pull
	$(MAKE) up
	@echo ""
	@echo 'Pronto. Para usar a AWS local neste terminal:  eval "$$(make -s env)"'

# Alvo interno (sem ##, então não aparece no help): serve de dependência.
# Padrão: `comando || { mensagem; exit 1; }` = se o comando falhar, explica
# o problema e para tudo com erro.
#   command -v docker  -> o programa existe?
#   docker info        -> o daemon responde? (2>&1 junta erro e saída)
check-docker:
	@command -v docker >/dev/null || { echo "Docker não encontrado. Instale o Docker (no WSL: ative a integração do Docker Desktop)."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Daemon do Docker inacessível. Inicie o Docker e tente de novo."; exit 1; }

# Aqui o alvo é um arquivo de verdade: o make só roda a receita se o .env
# NÃO existir. Por isso o `make build` nunca sobrescreve um .env editado.
# O .env é só uma cópia do exemplo, sem caminho nenhum dentro.
.env:
	cp .env.example .env

sync: ## Instala as dependências Python (uv)
	@command -v uv >/dev/null || { echo "uv não encontrado: https://docs.astral.sh/uv/"; exit 1; }
	uv sync


# ---- Dia a dia: ligar, desligar, observar -----------------------------------

# Sobe o container e espera o Floci responder de verdade (subir o container
# não significa que o serviço já está pronto).
# O \ no fim de cada linha junta tudo em UM comando só para o shell. Sem ele,
# cada linha viraria um shell separado e o laço for quebraria.
#   $$(seq 1 60)       -> 1, 2, ... 60: até 60 tentativas, uma por segundo
#   curl -f            -> falha se o servidor devolver erro HTTP
#   curl -sS           -> silencioso, mas ainda mostra erros
#   exit 0             -> achou o Floci no ar: termina com sucesso
# Se o laço acabar sem sucesso, mostra os últimos logs e sai com erro.
up: check-docker .env ## Sobe o Floci e espera ficar saudável
	$(COMPOSE) up -d
	@printf "Aguardando o Floci"; \
	for i in $$(seq 1 60); do \
	  if curl -fsS $(HEALTH_URL) >/dev/null 2>&1; then echo " ok -> http://localhost:4566"; exit 0; fi; \
	  printf "."; sleep 1; \
	done; echo " timeout"; $(COMPOSE) logs --tail=50; exit 1

down: ## Para o Floci (mantém os dados)
	$(COMPOSE) down

# Sem corpo: só encadeia dois alvos, na ordem (down e depois up).
restart: down up ## Reinicia

logs: ## Acompanha os logs
	$(COMPOSE) logs -f floci

# `a && b || c`: se `a && b` funcionar, não roda o c; se algo falhar, roda o c.
status: ## Estado do container e do endpoint
	@$(COMPOSE) ps
	@curl -fsS $(HEALTH_URL) && echo || echo "Floci não responde"

# Usa o floci CLI se ele estiver instalado; se não, cai no status.
doctor: ## Diagnóstico (usa o floci CLI se estiver instalado)
	@command -v floci >/dev/null && floci doctor || { echo "floci CLI ausente; usando checagens básicas"; $(MAKE) status; }

# Imprime comandos "export" para configurar o terminal. Primeiro, o que vem
# do .env.example, passando por três filtros do sed:
#   /^#/d          -> apaga linhas que começam com # (comentários)
#   /^$$/d         -> apaga linhas vazias (^ começo, $ fim da linha;
#                     o $ aparece duplicado por causa do make)
#   s/^/export /   -> põe "export " no começo de cada linha
# Depois, o caminho do aws/config, calculado agora com $(CURDIR).
# O %q do printf protege o caminho (espaços, & e aspas) para o eval não
# quebrar em pastas com nomes esquisitos.
# Uso: eval "$(make -s env)"
env: ## Imprime as variáveis de ambiente (use: eval $$(make -s env))
	@sed -e '/^#/d' -e '/^$$/d' -e 's/^/export /' .env.example
	@printf 'export AWS_CONFIG_FILE=%q\n' '$(CURDIR)/aws/config'


# ---- Testes -----------------------------------------------------------------

# Teste de fumaça: cria um bucket, sobe um arquivo, baixa de volta e compara.
#
# Pontos que merecem atenção:
#   B=data-lab-test-$$$$   -> $$$$ chega ao shell como $$, que é o número do
#                             processo (PID); dá um nome único ao bucket.
#   T=$$(mktemp -d)        -> pasta temporária só para este teste.
#   cmp A B                -> compara os arquivos byte a byte; falha se diferirem.
#   R=$$?                  -> guarda o resultado do teste ANTES da limpeza,
#                             senão o rb/rm mascarariam uma falha.
#   exit $$R               -> devolve o resultado original no fim.
# A limpeza (rb --force e rm -rf) roda de qualquer jeito, passando ou não.
test: ## Teste de fumaça: cria bucket, envia, baixa e compara um arquivo
	@command -v aws >/dev/null || { echo "AWS CLI não encontrada."; exit 1; }
	@curl -fsS $(HEALTH_URL) >/dev/null || { echo "Floci não está rodando. Rode: make up"; exit 1; }
	@$(LOAD_ENV); \
	B=data-lab-test-$$$$; T=$$(mktemp -d); \
	echo "ola data-lab" > $$T/in.txt; \
	aws s3 mb s3://$$B >/dev/null && \
	aws s3 cp $$T/in.txt s3://$$B/in.txt >/dev/null && \
	aws s3 cp s3://$$B/in.txt $$T/out.txt >/dev/null && \
	cmp $$T/in.txt $$T/out.txt && echo "OK: S3 (criar, enviar, baixar)"; \
	R=$$?; \
	aws s3 rb s3://$$B --force >/dev/null 2>&1; rm -rf $$T; \
	exit $$R

# Teste de persistência: grava, reinicia o Floci e vê se o dado continua lá.
# Foi ele que pegou o problema de o Floci estar em modo "memory".
#   aws s3 cp - destino  -> o "-" lê o conteúdo da entrada padrão (o echo)
#   || true              -> se o bucket já existir, tudo bem, segue em frente
#   --no-print-directory -> evita o "Entering directory" do make recursivo
test-persist: ## Teste de persistência: grava, reinicia e confere se os dados continuam
	@$(LOAD_ENV); \
	B=data-lab-persist; \
	aws s3 mb s3://$$B >/dev/null 2>&1 || true; \
	echo "persistente" | aws s3 cp - s3://$$B/p.txt >/dev/null && \
	$(MAKE) --no-print-directory restart >/dev/null && \
	aws s3 ls s3://$$B/p.txt >/dev/null && echo "OK: dados sobreviveram ao restart"; \
	R=$$?; \
	aws s3 rb s3://$$B --force >/dev/null 2>&1; \
	exit $$R


# ---- Limpeza ----------------------------------------------------------------

# Cuidado: o -v apaga também o volume, ou seja, TODOS os dados do Floci.
clean: ## Remove container e volume de dados
	$(COMPOSE) down -v
