NAME = inception
COMPOSE_FILE = srcs/docker-compose.yml
COMPOSE = docker compose -f $(COMPOSE_FILE)

all: up

build:
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
	@docker volume prune -f
	@docker network prune -f

.PHONY: all build up down re clean fclean
