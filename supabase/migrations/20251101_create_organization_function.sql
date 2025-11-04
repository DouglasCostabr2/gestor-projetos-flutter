-- Create a function to create organizations
-- This function bypasses RLS and ensures proper creation

-- Drop function if exists
DROP FUNCTION IF EXISTS public.create_organization(text, text, text, text, text);

-- Create function to create organization
CREATE OR REPLACE FUNCTION public.create_organization(
  p_name text,
  p_slug text,
  p_legal_name text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_phone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_org_id uuid;
  v_organization jsonb;
BEGIN
  -- Get authenticated user ID
  v_user_id := auth.uid();
  
  -- Check if user is authenticated
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  -- Check if slug already exists
  IF EXISTS (SELECT 1 FROM organizations WHERE slug = p_slug) THEN
    RAISE EXCEPTION 'Slug já existe: %', p_slug;
  END IF;

  -- Insert organization
  INSERT INTO organizations (
    name,
    slug,
    legal_name,
    email,
    phone,
    owner_id,
    status
  ) VALUES (
    p_name,
    p_slug,
    p_legal_name,
    p_email,
    p_phone,
    v_user_id,
    'active'
  )
  RETURNING id INTO v_org_id;

  -- Add user as owner in organization_members
  INSERT INTO organization_members (
    organization_id,
    user_id,
    role,
    status,
    invited_by,
    joined_at
  ) VALUES (
    v_org_id,
    v_user_id,
    'owner',
    'active',
    v_user_id,
    NOW()
  );

  -- Get the created organization
  SELECT jsonb_build_object(
    'id', id,
    'name', name,
    'slug', slug,
    'legal_name', legal_name,
    'email', email,
    'phone', phone,
    'owner_id', owner_id,
    'status', status,
    'created_at', created_at,
    'updated_at', updated_at
  )
  INTO v_organization
  FROM organizations
  WHERE id = v_org_id;

  RETURN v_organization;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.create_organization(text, text, text, text, text) TO authenticated;

-- Add comment
COMMENT ON FUNCTION public.create_organization IS 'Creates a new organization and adds the current user as owner';

