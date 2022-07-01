#!/bin/bash

if [ -n "${LIFERAY_SEARCH_ADDRESSES}" ]
then
	echo "operationMode=\"REMOTE\"" > "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config"
	echo "productionModeEnabled=B\"true\"" >> "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config"
	echo "networkHostAddresses=\"${LIFERAY_SEARCH_ADDRESSES}\"" >> "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config"
fi