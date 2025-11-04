-- Migration: Add social_networks field to clients table
-- Date: 2025-10-30
-- Description: Add JSONB field to store multiple social networks for each client

-- Add social_networks column to clients table
ALTER TABLE clients
ADD COLUMN social_networks JSONB DEFAULT '[]'::jsonb;

-- Add index for better query performance when searching social networks
CREATE INDEX idx_clients_social_networks ON clients USING GIN (social_networks);

-- Add comment to document the column
COMMENT ON COLUMN clients.social_networks IS 'Array de objetos JSON contendo redes sociais do cliente. Formato: [{"name": "Instagram", "url": "@usuario"}, {"name": "Facebook", "url": "https://facebook.com/usuario"}]';

