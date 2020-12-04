registry ?= fengsiio
version  ?= 12

.PHONY: nginx worker socketio push clean test
.ONESHELL: worker nginx socketio clean

all: worker push

build: worker socketio nginx

worker nginx socketio: Dockerfile
	@if [ "$@" = "worker" ]; then
		image=$(registry)/erpnext:$(version)
	else
		image=$(registry)/erpnext-$@:$(version)
	fi
	@docker build --progress plain --file $^ \
		--pull --force-rm \
		--build-arg http_proxy \
		--build-arg https_proxy \
		--build-arg no_proxy \
		--build-arg version=$(version) \
		--target $@ \
		-t $$image .

push:
	@for i in worker nginx socketio; do
		if [ "$$i" = "worker" ]; then
			docker push $(registry)/erpnext:$(version)
			continue
		fi
		docker push $(registry)/erpnext-$$i:$(version)
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
