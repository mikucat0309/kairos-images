ARG ALPINE_VERSION
ARG KAIROS_INIT_VERSION
ARG AURORABOOT_VERSION
ARG KUBESOLO_VERSION
ARG KUBESOLO_VARIANT=musl

FROM quay.io/kairos/kairos-init:${KAIROS_INIT_VERSION} AS kairos-init
FROM --platform=$BUILDPLATFORM quay.io/kairos/auroraboot:${AURORABOOT_VERSION} AS auroraboot

FROM --platform=$BUILDPLATFORM docker.io/library/alpine:${ALPINE_VERSION} AS kubesolo
ARG TARGETARCH
ARG KUBESOLO_VERSION
ARG KUBESOLO_VARIANT
WORKDIR /tmp
RUN <<'EOF'
set -eu
name="kubesolo-${KUBESOLO_VERSION}-linux-${TARGETARCH}-${KUBESOLO_VARIANT}.tar.gz"
base="https://github.com/portainer/kubesolo/releases/download/${KUBESOLO_VERSION}"
wget -q "$base/$name" "$base/SHA256SUMS"
grep " $name\$" SHA256SUMS | sha256sum -c -
tar -xzf "$name" -C / kubesolo
EOF

FROM docker.io/library/alpine:${ALPINE_VERSION}
ARG TARGETARCH
ARG VERSION

RUN apk add --no-cache linux-virt iptables nftables

RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -m generic --version "$VERSION" --skip-step installKernel

RUN <<'EOF'
set -eu
rc-update del fail2ban boot
apk del --no-cache fail2ban
rc-update del connman boot
apk del --no-cache connman wpa_supplicant
apk add --no-cache ifupdown-ng
rc-update add networking boot
EOF

RUN ln -sf /boot/vmlinuz-virt /boot/vmlinuz

RUN --mount=type=bind,from=auroraboot,src=/,dst=/auroraboot <<'EOF'
set -eu
case "$TARGETARCH" in
  amd64) src=amd; dir=x86_64 ;;
  arm64) src=arm; dir=aarch64 ;;
  *) echo "unsupported arch $TARGETARCH"; exit 1 ;;
esac
mkdir -p /usr/share/efi/$dir
for f in grub.efi shim.efi; do
    install -m 0644 /auroraboot/$src/raw/grubartifacts/EFI/BOOT/grub.efi /usr/share/efi/$dir/$f
done
EOF

COPY --from=kubesolo --chown=0:0 --chmod=0755 /kubesolo /usr/bin/kubesolo
COPY files/ /
RUN <<'EOF'
set -eu
chmod 0755 /etc/init.d/kubesolo
chmod 0600 /etc/kubesolo/config.yaml
EOF
