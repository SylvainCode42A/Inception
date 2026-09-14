# := évalue une seule fois, à la lecture du fichier.
# Toutes les cibles passent par ce même docker-compose.yml.
COMPOSE  := docker compose -f srcs/docker-compose.yml
DATA_DIR := /home/slidriss/data

# Cible par défaut : un "make" nu construit et démarre tout.
all: up

# Les volumes utilisent o: bind, donc ces dossiers doivent exister sur
# l'hôte avant le premier lancement, sinon Docker refuse de les monter.
setup:
	@mkdir -p $(DATA_DIR)/db_data $(DATA_DIR)/wp_data

# -d détache le terminal. --build reconstruit les images dès qu'un
# Dockerfile ou un script copié a changé — sans lui, une correction
# d'entrypoint ne serait jamais prise en compte. Nécessite buildx.
up: setup
	$(COMPOSE) up -d --build

# Supprime les conteneurs et le réseau, GARDE les volumes :
# le site survit à un make down.
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

# -v supprime les volumes, --rmi local les images construites ici.
# Les données sont perdues : le prochain démarrage rejoue les deux
# initialisations depuis zéro.
clean:
	$(COMPOSE) down -v --rmi local

# prune -af nettoie TOUT Docker sur la machine, pas seulement ce projet.
# Sans danger sur une VM dédiée, à ne pas lancer ailleurs.
fclean: clean
	@sudo rm -rf $(DATA_DIR)/db_data $(DATA_DIR)/wp_data
	@docker system prune -af

# Déclare ces noms comme des actions et non des fichiers à produire :
# sans ça, un fichier nommé "clean" dans le dossier empêcherait la règle
# de s'exécuter.
.PHONY: all setup up down stop start re logs ps clean fclean