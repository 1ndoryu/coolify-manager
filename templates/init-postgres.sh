#!/bin/bash
set -e

# Activar extension pgvector en la base de datos kamples
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;"

echo "[SUCCESS] pgvector activado en base de datos $POSTGRES_DB"
