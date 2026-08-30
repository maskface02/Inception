NAME = inception
COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE = docker compose -f $(COMPOSE_FILE)

all: up

build:
	@mkdir -p /home/$(USER)/data/wordpress /home/$(USER)/data/mariadb
	@$(COMPOSE) build

up: build
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

re: fclean all

clean:
	@$(COMPOSE) down

fclean: clean
	@docker system prune -af
	@sudo rm -rf ~/data/wordpress ~/data/mariadb
	@docker network prune -f

.PHONY: all build up down re clean fclean
