# Backup volume

Have the backup volume mounted on `/opt/liferay/backups` as the persistent storage of the backup data. 

# Liferay persistent data

Have Liferay's shared data volume mounted on `/opt/liferay/liferay/data`, so the `backup` docker image can copy it to the backup volume.
