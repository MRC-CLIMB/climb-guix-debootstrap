IMAGE_PREFIX?=climb-guix-vm
S3_BUCKET?=climb-images

TODAY := $(shell date +%Y-%m-%d)
GIT_VERSION := $(shell git rev-parse --short HEAD)

IMAGE_NAME?=$(IMAGE_PREFIX)-$(TODAY)-$(GIT_VERSION)
IMAGE_FILENAME?=$(IMAGE_NAME).img

vm:
	test -f $(IMAGE_FILENAME) || IMAGE_NAME=$(IMAGE_FILENAME) sh vmdebootstrap.sh

glance-upload: vm
	glance image-create --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi \
	--property hw_qemu_guest_agent=yes --property os_require_quiesce=yes \
	--name $(IMAGE_NAME) --min-ram 256 --disk-format raw \
	--container-format bare --visibility public < $(IMAGE_FILENAME)

s3-upload: vm
	s3cmd put -P $(IMAGE_FILENAME) s3://$(S3_BUCKET)

clean:
	rm -f $(IMAGE_PREFIX)*
