#!/bin/bash
set -e

# Restore the database if it does not already exist.
if [ -f "$DB_FILENAME" ]; then
	echo "Database already exists, skipping restore"
else
	echo "No database found, restoring from replica if exists"
	litestream restore -if-db-not-exists -if-replica-exists -o "${DB_FILENAME}" "${DB_REPLICA_URL}"
fi

# Run litestream with your app as the subprocess.
litestream replicate -exec "node cli.js bootstrap && pm2-runtime start ecosystem.config.cjs"
