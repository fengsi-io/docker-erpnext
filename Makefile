registry ?= fengsiio
version  ?= 12

.PHONY: erpnext erpnext-nginx erpnext-socketio push clean test
.ONESHELL: erpnext erpnext-nginx erpnext-socketio clean

all: worker push

build: erpnext erpnext-nginx erpnext-socketio

erpnext erpnext-nginx erpnext-socketio: Dockerfile
	@docker build --progress plain --file $^ \
		--pull --force-rm \
		--build-arg http_proxy \
		--build-arg https_proxy \
		--build-arg no_proxy \
		--build-arg VERSION=$(version) \
		--target $@ \
		-t $(registry)/erpnext-$@:v$(version) .

push:
	@for i in erpnext erpnext-nginx erpnext-socketio; do
		docker push $(registry)/erpnext-$$i:v$(version)
	done

test:
	@docker-compose up -d --remove-orphans;
	@docker-compose logs -ft;

clean:
	@docker-compose down
	@basename=$$(basename $$(pwd))
	@volumes=$$(docker volume ls -f "name=$$basename" --format="{{.Name}}");
	@for volume in $$volumes; do \
		docker volume rm $$volume; \
	done
