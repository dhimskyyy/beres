-- ============================================================================
-- BERES PLATFORM - MIGRATION 0013: AUTO SYNC PROFILE ON OAUTH (GOOGLE) SIGN-IN
-- ============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_full_name TEXT;
  v_avatar_url TEXT;
BEGIN
  v_full_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    INITCAP(SPLIT_PART(NEW.email, '@', 1))
  );

  v_avatar_url := COALESCE(
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'picture'
  );

  INSERT INTO public.profiles (id, email, full_name, role, avatar_url)
  VALUES (
    NEW.id,
    LOWER(NEW.email),
    v_full_name,
    'USER',
    v_avatar_url
  )
  ON CONFLICT (id) DO UPDATE
  SET full_name = CASE 
        WHEN public.profiles.full_name IN ('Pengguna Beres', 'Pelanggan Beres') AND EXCLUDED.full_name NOT IN ('Pengguna Beres', 'Pelanggan Beres')
        THEN EXCLUDED.full_name 
        ELSE public.profiles.full_name 
      END,
      avatar_url = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url);

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user();
