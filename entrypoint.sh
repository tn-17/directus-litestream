#!/bin/bash
set -e

# Restore the database if it does not already exist.
if [ -f "$DB_FILENAME" ]; then
	echo "Database already exists, skipping restore"
else
	echo "No database found, restoring from replica if exists"
	litestream restore -if-replica-exists "${DB_FILENAME}"
fi

# Bootstrap Directus
node cli.js bootstrap

# Run litestream with your app as the subprocess.
litestream replicate -exec "pm2-runtime start ecosystem.config.cjs"
