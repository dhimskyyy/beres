'use client';

import React, { useState, useEffect, Suspense } from 'react';
import { useSearchParams } from 'next/navigation';
import { Lock, Eye, EyeOff, CheckCircle2, AlertCircle, ShieldCheck } from 'lucide-react';
import { supabase } from '@/lib/supabase';

function ResetPasswordContent() {
  const searchParams = useSearchParams();

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [isVerifying, setIsVerifying] = useState(true);
  const [isReady, setIsReady] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isSuccess, setIsSuccess] = useState(false);

  useEffect(() => {
    async function initRecovery() {
      setIsVerifying(true);
      setErrorMessage(null);

      // 0. Cek parameter error langsung dari Supabase redirect
      const errorParam = searchParams.get('error') || searchParams.get('error_code');
      const errorDesc = searchParams.get('error_description');
      if (errorParam) {
        if (
          errorParam.toLowerCase().includes('expired') ||
          (errorDesc && errorDesc.toLowerCase().includes('expired'))
        ) {
          setErrorMessage(
            'Tautan pemulihan kata sandi telah kedaluwarsa karena telah melewati batas waktu 1 jam. Silakan buka aplikasi Beres di ponsel Anda dan klik "Lupa Password?" kembali untuk mendapatkan email tautan baru.'
          );
        } else {
          setErrorMessage(
            errorDesc || 'Tautan pemulihan kata sandi tidak valid atau telah digunakan sebelumnya.'
          );
        }
        setIsVerifying(false);
        return;
      }

      try {
        // 1. Ambil code dari query param atau hash
        const authCode = searchParams.get('code');
        if (!authCode && typeof window !== 'undefined') {
          const hash = window.location.hash;
          if (hash.includes('access_token=')) {
            // Implicit grant fragment
            const { data } = await supabase.auth.getSession();
            if (data.session) {
              setIsReady(true);
              setIsVerifying(false);
              return;
            }
          }
        }

        if (authCode) {
          // Tukar code dengan session
          const { error } = await supabase.auth.exchangeCodeForSession(authCode);
          if (error) {
            // Cek apakah session sudah aktif
            const { data: sessionData } = await supabase.auth.getSession();
            if (!sessionData.session) {
              throw error;
            }
          }
          setIsReady(true);
        } else {
          // Cek apakah user sudah punya active recovery session
          const { data: sessionData } = await supabase.auth.getSession();
          if (sessionData.session) {
            setIsReady(true);
          } else {
            setErrorMessage('Tautan pemulihan tidak memiliki kode autentikasi yang valid. Silakan ajukan ulang dari aplikasi Beres.');
          }
        }
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : String(err);
        setErrorMessage(`Tautan telah kedaluwarsa atau tidak valid: ${msg}. Silakan ajukan ulang melalui menu Lupa Password di aplikasi.`);
      } finally {
        setIsVerifying(false);
      }
    }

    initRecovery();
  }, [searchParams]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newPassword || newPassword.length < 6) {
      setErrorMessage('Password minimal harus terdiri dari 6 karakter.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setErrorMessage('Konfirmasi password tidak cocok.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const { error } = await supabase.auth.updateUser({
        password: newPassword,
      });

      if (error) {
        throw error;
      }

      setIsSuccess(true);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Gagal memperbarui password. Silakan coba lagi.';
      setErrorMessage(msg);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col justify-center items-center p-4">
      <div className="max-w-md w-full">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-blue-600/10 border border-blue-500/20 text-blue-500 mb-4 shadow-lg shadow-blue-500/10">
            <ShieldCheck className="w-8 h-8" />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">BERES</h1>
          <p className="text-xs text-slate-400 mt-1">Platform Marketplace Jasa Pertukangan</p>
        </div>

        {/* Card */}
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 sm:p-8 shadow-2xl relative overflow-hidden">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-blue-600 via-amber-500 to-blue-500" />

          {isVerifying ? (
            <div className="py-12 text-center text-slate-400 space-y-3">
              <div className="w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto" />
              <p className="text-sm">Memverifikasi tautan pemulihan kata sandi...</p>
            </div>
          ) : isSuccess ? (
            <div className="py-6 text-center space-y-4">
              <div className="w-16 h-16 rounded-full bg-emerald-500/20 border border-emerald-500/30 text-emerald-400 flex items-center justify-center mx-auto">
                <CheckCircle2 className="w-10 h-10" />
              </div>
              <h2 className="text-xl font-bold text-white">Password Berhasil Diperbarui!</h2>
              <p className="text-sm text-slate-300 leading-relaxed">
                Kata sandi baru untuk akun Anda telah aktif. Silakan buka aplikasi <strong>Beres</strong> di smartphone Anda dan masuk menggunakan password baru.
              </p>
              <div className="pt-4">
                <div className="text-xs text-slate-500">
                  Anda dapat menutup tab browser ini sekarang.
                </div>
              </div>
            </div>
          ) : errorMessage && !isReady ? (
            <div className="py-6 text-center space-y-4">
              <div className="w-16 h-16 rounded-full bg-red-500/20 border border-red-500/30 text-red-400 flex items-center justify-center mx-auto">
                <AlertCircle className="w-10 h-10" />
              </div>
              <h2 className="text-lg font-bold text-white">Tautan Tidak Valid atau Kedaluwarsa</h2>
              <p className="text-xs text-slate-400 leading-relaxed">
                {errorMessage}
              </p>
            </div>
          ) : (
            <div>
              <div className="mb-6">
                <h2 className="text-lg font-bold text-white">Atur Ulang Password</h2>
                <p className="text-xs text-slate-400 mt-1">
                  Buat password baru yang aman untuk akun Beres Anda.
                </p>
              </div>

              {errorMessage && (
                <div className="mb-5 p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Password Baru
                  </label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showPassword ? 'text' : 'password'}
                      value={newPassword}
                      onChange={(e) => setNewPassword(e.target.value)}
                      placeholder="Minimal 6 karakter"
                      required
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-10 pr-10 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
                    >
                      {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1.5">
                    Konfirmasi Password Baru
                  </label>
                  <div className="relative">
                    <Lock className="w-4 h-4 text-slate-500 absolute left-3.5 top-1/2 -translate-y-1/2" />
                    <input
                      type={showConfirmPassword ? 'text' : 'password'}
                      value={confirmPassword}
                      onChange={(e) => setConfirmPassword(e.target.value)}
                      placeholder="Ulangi password baru"
                      required
                      className="w-full bg-slate-950 border border-slate-800 rounded-xl pl-10 pr-10 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-500 hover:text-slate-300"
                    >
                      {showConfirmPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full mt-2 py-3 px-4 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white text-xs font-bold rounded-xl transition-all shadow-lg shadow-blue-600/20"
                >
                  {isLoading ? 'Menyimpan Password...' : 'Simpan Password Baru'}
                </button>
              </form>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function ResetPasswordPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400 text-sm">
          Memuat...
        </div>
      }
    >
      <ResetPasswordContent />
    </Suspense>
  );
}
