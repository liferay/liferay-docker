FROM liferay/dxp AS liferay-image

FROM azul/zulu-openjdk-alpine

COPY --from=liferay-image /opt/liferay /opt/liferay
COPY --from=liferay-image /usr/local/bin /usr/local/bin

ENTRYPOINT ["tini", "--", "/usr/local/bin/liferay_entrypoint.sh"]

ENV LIFERAY_HOME=/opt/liferay
ENV LIFERAY_PID="${LIFERAY_HOME}/liferay.pid"
ENV LIFERAY_PRODUCT_NAME=Liferay

EXPOSE 8000 8009 8080 11311

RUN apk add bash tini

WORKDIR /opt/liferay