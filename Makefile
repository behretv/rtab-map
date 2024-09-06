TAG := $(shell git tag --sort=committerdate | tail -1)

lint:
	docker run --rm \
		-v "$(shell pwd):/app" \
		-e UID="${UID}" \
		--pull=always \
		behretv/lint:latest

build:
	docker build --pull \
	 --build-arg BASE_IMAGE=behretv/rtab-map-dependencies:latest \
   --build-arg CATKIN_WS=/root/catkin_ws \
   --build-arg ROS_DISTRO=iron \
   --build-arg UBUNTU_VERSION=20.04 \
	 --build-arg RTABMAP_TAG=0.21.4-iron \
   --file Dockerfile \
   --tag behretv/rtab-map:${TAG} \
	 .

