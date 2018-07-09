docker:
	docker build \
		-t newinstall-testenv \
		--pull=true \
		--build-arg D_USER="$(shell id -un)" \
		--build-arg D_UID="$(shell id -u)" \
		--build-arg D_GROUP="$(shell id -gn)" \
		--build-arg D_GID="$(shell id -g)" \
		--build-arg D_HOME="$(HOME)" \
		.
