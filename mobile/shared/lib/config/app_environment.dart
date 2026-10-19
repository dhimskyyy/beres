/// Konfigurasi Environment Global untuk Aplikasi Mobile Beres v1.4.0
class AppEnvironment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uxfxlfaqgyoifxyqxfls.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV4ZnhsZmFxZ3lvaWZ4eXF4ZmxzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MTg2MDYsImV4cCI6MjEwNzk5NDYwNn0.8mDqHinvIXGSUKikSzFZbdI-KdJcLEK8Nhue3wbkdGk',
  );
}
