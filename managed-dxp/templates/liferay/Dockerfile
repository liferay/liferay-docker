FROM liferay/dxp:7.4.13-u31-d4.1.4-20220629111505

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY --chown=liferay:liferay resources/opt/liferay /opt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

ENV LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_STORE_PERIOD_FILE_PERIOD_SYSTEM_PERIOD_CONFIGURATION_PERIOD__UPPERCASEA_DVANCED_UPPERCASEF_ILE_UPPERCASES_YSTEM_UPPERCASES_TORE_UPPERCASEC_ONFIGURATION_UNDERLINE_ROOT_UPPERCASED_IR="/opt/liferay/shared-volume/document-library"

USER liferay

RUN /usr/local/bin/install_patch_on_build.sh