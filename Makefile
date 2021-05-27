registry ?= fengsiio
version  ?= 13

.PHONY: erpnext erpnext-nginx erpnext-socketio push clean test
.ONESHELL: erpnext erpnext-nginx erpnext-socketio clean

all: worker push

build: build-nginx build-socketio build-erpnext

build-%: docker-compose.yml
	@docker-compose build $*

push: push-nginx push-socketio push-erpnext

push-%: build-%
	@[ "$*" == "erpnext" ] && docker push fengsiio/erpnext:$(version) || docker push fengsiio/frappe-$*:$(version)

test:
	@docker-compose up -d --remove-orphans --no-build;
	@docker-compose logs -ft;

clean:
	@docker-compose down
	@basename=$$(basename $$(pwd))
	@volumes=$$(docker volume ls -f "name=$$basename" --format="{{.Name}}");
	@for volume in $$volumes; do \
		docker volume rm $$volume; \
	done
