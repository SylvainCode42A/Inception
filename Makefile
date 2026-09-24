COMPOSE  := docker compose -f srcs/docker-compose.yml
DATA_DIR := /home/slidriss/data

all: up

setup:
	@mkdir -p $(DATA_DIR)/db_data $(DATA_DIR)/wp_data

up: setup
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

re: down up

logs:
	$(COMPOSE) logs -f

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v --rmi local

fclean: clean
	@sudo rm -rf $(DATA_DIR)/db_data $(DATA_DIR)/wp_data
	@docker system prune -af

.PHONY: all setup up down stop start re logs ps clean fclean