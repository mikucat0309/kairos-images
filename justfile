arch := "amd64"

version := "0.1.0"
alpine_version := "3.24"
kairos_init_version := "v0.17.3"
kubesolo_version := "v1.2.3"
auroraboot_version := "v0.27.1"

image_repo := "ghcr.io/mikucat0309/kairos"
image_tag := alpine_version + "-core-" + arch + "-generic-" + version + "-kubesolo-" + kubesolo_version
image := image_repo + ":" + image_tag
auroraboot := "quay.io/kairos/auroraboot:" + auroraboot_version
build_dir := justfile_directory() / "build"

default:
    @just --list

build:
    sudo docker build \
        --platform linux/{{ arch }} \
        --build-arg VERSION={{ version }} \
        --build-arg ALPINE_VERSION={{ alpine_version }} \
        --build-arg KAIROS_INIT_VERSION={{ kairos_init_version }} \
        --build-arg KUBESOLO_VERSION={{ kubesolo_version }} \
        --build-arg AURORABOOT_VERSION={{ auroraboot_version }} \
        -t {{ image }} \
        {{ justfile_directory() }}

iso: build
    mkdir -p {{ build_dir }}
    sudo docker run --rm --privileged \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v {{ build_dir }}:/output \
        {{ auroraboot }} build-iso \
        --arch {{ arch }} \
        --output /output/ docker:{{ image }}
    sudo chown -R "$USER:$USER" {{ build_dir }}

clean:
    -sudo docker image rm {{ image }}
    rm -rf {{ build_dir }}
