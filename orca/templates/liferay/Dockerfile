#FROM liferay/dxp:7.4.13-u45-d5.0.1-20221006125539
FROM liferay/dxp@sha256:8a288a450ca6835e2fa4a3d47f302d4f46ea69a7a467f0ba5ecbda1c674981a4

USER 0

COPY --chown=liferay:liferay resources/opt/liferay /opt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

USER liferay

RUN /usr/local/bin/install_patch_on_build.sh
