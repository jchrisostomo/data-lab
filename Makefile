SHELL := /bin/bash
.DEFAULT_GOAL := help
COMPOSE := docker compose
HEALTH_URL := http://localhost:4566/_floci/health

.PHONY: help build up down restart logs status doctor env test test-persist clean

help: ## Lista os comandos
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  make %-14s %s\n",$$1,$$2}'

build: check-docker .env sync ## Primeira vez: prepara tudo e sobe o Floci
	$(COMPOSE) pull
	$(MAKE) up
	@echo ""
	@echo "Pronto. Para usar a AWS local neste terminal:  source .env  (ou: set -a; source .env; set +a)"

check-docker:
	@command -v docker >/dev/null || { echo "Docker não encontrado. Instale o Docker (no WSL: ative a integração do Docker Desktop)."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Daemon do Docker inacessível. Inicie o Docker e tente de novo."; exit 1; }

.env:
	cp .env.example .env

sync: ## Instala as dependências Python (uv)
	@command -v uv >/dev/null || { echo "uv não encontrado: https://docs.astral.sh/uv/"; exit 1; }
	uv sync

up: check-docker .env ## Sobe o Floci e espera ficar saudável
	$(COMPOSE) up -d
	@printf "Aguardando o Floci"; \
	for i in $$(seq 1 60); do \
	  if curl -fsS $(HEALTH_URL) >/dev/null 2>&1; then echo " ok -> http://localhost:4566"; exit 0; fi; \
	  printf "."; sleep 1; \
	done; echo " timeout"; $(COMPOSE) logs --tail=50; exit 1

down: ## Para o Floci (mantém os dados)
	$(COMPOSE) down

restart: down up ## Reinicia

logs: ## Acompanha os logs
	$(COMPOSE) logs -f floci

status: ## Estado do container e do endpoint
	@$(COMPOSE) ps
	@curl -fsS $(HEALTH_URL) && echo || echo "Floci não responde"

doctor: ## Diagnóstico (usa o floci CLI se estiver instalado)
	@command -v floci >/dev/null && floci doctor || { echo "floci CLI ausente; usando checagens básicas"; $(MAKE) status; }

env: ## Imprime as variáveis de ambiente (use: eval $$(make -s env))
	@sed -e '/^#/d' -e '/^$$/d' -e 's/^/export /' .env.example

test: ## Teste de fumaça: cria bucket, envia, baixa e compara um arquivo
	@command -v aws >/dev/null || { echo "AWS CLI não encontrada."; exit 1; }
	@curl -fsS $(HEALTH_URL) >/dev/null || { echo "Floci não está rodando. Rode: make up"; exit 1; }
	@set -a; . ./.env; set +a; \
	B=data-lab-test-$$$$; T=$$(mktemp -d); \
	echo "ola data-lab" > $$T/in.txt; \
	aws s3 mb s3://$$B >/dev/null && \
	aws s3 cp $$T/in.txt s3://$$B/in.txt >/dev/null && \
	aws s3 cp s3://$$B/in.txt $$T/out.txt >/dev/null && \
	cmp $$T/in.txt $$T/out.txt && echo "OK: S3 (criar, enviar, baixar)"; \
	R=$$?; \
	aws s3 rb s3://$$B --force >/dev/null 2>&1; rm -rf $$T; \
	exit $$R

test-persist: ## Teste de persistência: grava, reinicia e confere se os dados continuam
	@set -a; . ./.env; set +a; \
	B=data-lab-persist; \
	aws s3 mb s3://$$B >/dev/null 2>&1 || true; \
	echo "persistente" | aws s3 cp - s3://$$B/p.txt >/dev/null && \
	$(MAKE) --no-print-directory restart >/dev/null && \
	aws s3 ls s3://$$B/p.txt >/dev/null && echo "OK: dados sobreviveram ao restart"; \
	R=$$?; \
	aws s3 rb s3://$$B --force >/dev/null 2>&1; \
	exit $$R

clean: ## Remove container e volume de dados
	$(COMPOSE) down -v

