registry ?= fengsiio
version  ?= 12

.PHONY: erpnext erpnext-nginx erpnext-socketio push clean test
.ONESHELL: erpnext erpnext-nginx erpnext-socketio clean

all: worker push

build: frappe-nginx frappe-socketio erpnext

frappe-nginx frappe-socketio erpnext: Dockerfile
	@docker build --file $^ \
		--progress plain \
		--force-rm \
		--build-arg http_proxy \
		--build-arg https_proxy \
		--build-arg no_proxy \
		--build-arg VERSION=$(version) \
		--target $@ \
		-t $(registry)/$@:v$(version) .

push:
	@for i in erpnext erpnext-nginx erpnext-socketio; do
		docker push $(registry)/$$i:v$(version)
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
