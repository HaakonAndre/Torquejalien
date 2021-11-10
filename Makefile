gitlab_base_image=gitlab-registry.cern.ch/jalien/jalien-setup/jalien-base
gitlab_xrootd_image=gitlab-registry.cern.ch/jalien/jalien-setup/xrootd-se

base-image:
	docker build -t jalien-base -f base/Dockerfile base --no-cache

xrootd-image:
	docker build -t xrootd-se -f xrootd/Dockerfile xrootd --no-cache

push-base: base-image xrootd-image
	docker tag jalien-base ${gitlab_base_image}
	docker push ${gitlab_base_image}

push-xrootd: xrootd-image
	docker tag xrootd-se ${gitlab_xrootd_image}
	docker push ${gitlab_xrootd_image}

pull-all:
	docker pull ${gitlab_base_image}
	docker pull ${gitlab_xrootd_image}

retag:
	docker tag ${gitlab_base_image} jalien-base
	docker tag ${gitlab_xrootd_image} xrootd-se

push-all: push-base push-xrootd
all: base-image xrootd-image

