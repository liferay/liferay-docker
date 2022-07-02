#!/bin/bash

echo "Cron expression: ${LIFERAY_BACKUP_CRON_EXPRESSION}"
echo "${LIFERAY_BACKUP_CRON_EXPRESSION} /usr/local/bin/register_job.sh backup" >> "/mnt/liferay/job-crontab"

/usr/local/bin/liferay_job_runner_entrypoint.sh