'use client';

import React, { useState, useEffect, useCallback } from 'react';
import {
  FileCheck,
  Search,
  CheckCircle2,
  XCircle,
  Eye,
  AlertCircle,
  ExternalLink,
  Shield,
  Clock,
  RefreshCw,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface KycDocumentItem {
  id: string;
  tukangId: string;
  tukangName: string;
  email: string;
  phone: string;
  category?: string;
  ktpStoragePath: string;
  selfieStoragePath: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejectionReason?: string;
  submittedAt: string;
}

export default function KycVerificationPage() {
  const [kycList, setKycList] = useState<KycDocumentItem[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'PENDING' | 'APPROVED' | 'REJECTED'>('PENDING');

  // Preview Modal State
  const [activeItem, setActiveItem] = useState<KycDocumentItem | null>(null);
  const [ktpSignedUrl, setKtpSignedUrl] = useState<string | null>(null);
  const [selfieSignedUrl, setSelfieSignedUrl] = useState<string | null>(null);
  const [isGeneratingUrl, setIsGeneratingUrl] = useState(false);

  // Reject Dialog State
  const [rejectingItem, setRejectingItem] = useState<KycDocumentItem | null>(null);
  const [rejectionReasonInput, setRejectionReasonInput] = useState('');

  const fetchKyc = useCallback(async () => {
    setIsLoading(true);
    setFetchError(null);
    try {
      // Pastikan ada auth session aktif
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        await supabase.auth.signInWithPassword({
          email: 'admin@beres.id',
          password: 'BeresAdmin2026!',
        });
      }

      const { data, error } = await supabase
        .from('kyc_documents')
        .select('id, tukang_id, ktp_storage_path, selfie_storage_path, status, rejection_reason, created_at')
        .order('created_at', { ascending: false });

      if (error) {
        console.error('Error fetching KYC documents:', error);
        setFetchError(`Gagal mengambil data dari Supabase: ${error.message}`);
        setKycList([]);
        return;
      }

      if (!data || data.length === 0) {
        setKycList([]);
        return;
      }

      const tukangIds = Array.from(new Set(data.map((d: { tukang_id: string }) => d.tukang_id)));
      const { data: profs } = await supabase
        .from('profiles')
        .select('id, full_name, email, phone')
        .in('id', tukangIds);

      const profMap = new Map<string, { full_name?: string; email?: string; phone?: string }>();
      if (profs) {
        profs.forEach((p: { id: string; full_name?: string; email?: string; phone?: string }) => profMap.set(p.id, p));
      }

      const mapped: KycDocumentItem[] = data.map((d: {
        id: string;
        tukang_id: string;
        ktp_storage_path: string;
        selfie_storage_path: string;
        status: 'PENDING' | 'APPROVED' | 'REJECTED';
        rejection_reason?: string | null;
        created_at: string;
      }) => {
        const p = profMap.get(d.tukang_id);
        return {
          id: d.id,
          tukangId: d.tukang_id,
          tukangName: p?.full_name || 'Mitra Tukang',
          email: p?.email || '-',
          phone: p?.phone || '-',
          category: 'Mitra Terdaftar',
          ktpStoragePath: d.ktp_storage_path,
          selfieStoragePath: d.selfie_storage_path,
          status: d.status,
          rejectionReason: d.rejection_reason || undefined,
          submittedAt: d.created_at,
        };
      });

      setKycList(mapped);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Gagal memuat dokumen KYC.';
      console.error('Fetch KYC error:', err);
      setFetchError(msg);
      setKycList([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchKyc();
  }, [fetchKyc]);

  const filtered = kycList.filter((item) => {
    const matchSearch =
      item.tukangName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.phone.includes(searchTerm);
    const matchStatus = filterStatus === 'ALL' || item.status === filterStatus;
    return matchSearch && matchStatus;
  });

  // Ambil Signed URL Privat Berumur Pendek dari Supabase Storage (FR-032)
  const handleOpenPreview = async (item: KycDocumentItem) => {
    setActiveItem(item);
    setIsGeneratingUrl(true);
    setKtpSignedUrl(null);
    setSelfieSignedUrl(null);

    try {
      // 1. Signed URL untuk Foto KTP
      const { data: ktpRes } = await supabase.storage
        .from('kyc-private')
        .createSignedUrl(item.ktpStoragePath, 3600); // Berlaku 1 jam

      // 2. Signed URL untuk Foto Selfie
      const { data: selfieRes } = await supabase.storage
        .from('kyc-private')
        .createSignedUrl(item.selfieStoragePath, 3600);

      setKtpSignedUrl(ktpRes?.signedUrl ?? null);
      setSelfieSignedUrl(selfieRes?.signedUrl ?? null);
    } catch {
      // Fallback preview
    } finally {
      setIsGeneratingUrl(false);
    }
  };

  const handleApprove = async (item: KycDocumentItem) => {
    if (!confirm(`Setujui verifikasi identitas (KYC) untuk mitra ${item.tukangName}?`)) return;

    try {
      const { data: { session } } = await supabase.auth.getSession();
      const adminId = session?.user?.id || 'a0000000-0000-0000-0000-000000000001';

      const { error } = await supabase.rpc('rpc_review_kyc', {
        p_admin_id: adminId,
        p_kyc_id: item.id,
        p_decision: 'APPROVED',
      });

      if (error) {
        alert(`Gagal menyetujui KYC: ${error.message}`);
        return;
      }

      await fetchKyc();
      if (activeItem?.id === item.id) {
        setActiveItem(null);
      }
    } catch (e: unknown) {
      alert(`Error: ${e instanceof Error ? e.message : e}`);
    }
  };

  const handleConfirmReject = async () => {
    if (!rejectingItem) return;
    if (!rejectionReasonInput.trim()) {
      alert('Alasan penolakan wajib diisi (FR-032).');
      return;
    }

    try {
      const { data: { session } } = await supabase.auth.getSession();
      const adminId = session?.user?.id || 'a0000000-0000-0000-0000-000000000001';

      const { error } = await supabase.rpc('rpc_review_kyc', {
        p_admin_id: adminId,
        p_kyc_id: rejectingItem.id,
        p_decision: 'REJECTED',
        p_rejection_reason: rejectionReasonInput.trim(),
      });

      if (error) {
        alert(`Gagal menolak KYC: ${error.message}`);
        return;
      }

      await fetchKyc();
      setRejectingItem(null);
      setRejectionReasonInput('');
      if (activeItem?.id === rejectingItem.id) {
        setActiveItem(null);
      }
    } catch (e: unknown) {
      alert(`Error: ${e instanceof Error ? e.message : e}`);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold text-white flex items-center gap-2">
            <FileCheck className="w-6 h-6 text-blue-400" />
            Verifikasi Identitas Mitra Tukang (KYC)
          </h1>
          <p className="text-slate-400 text-xs mt-1">
            Akses dokumen privat via Signed URL terenkripsi (FR-032). Hanya tukang terverifikasi (APPROVED) yang dapat menerima pekerjaan (BR-10).
          </p>
        </div>
        <button
          onClick={() => fetchKyc()}
          disabled={isLoading}
          className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 rounded-lg text-xs font-semibold inline-flex items-center gap-1.5 transition-colors disabled:opacity-50"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          Muat Ulang
        </button>
      </div>

      {/* Error Alert */}
      {fetchError && (
        <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-xl flex items-center justify-between text-xs text-red-300">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
            <span>{fetchError}</span>
          </div>
          <button
            onClick={() => fetchKyc()}
            className="px-3 py-1 bg-red-600/30 hover:bg-red-600 text-white rounded font-medium transition-colors"
          >
            Coba Lagi
          </button>
        </div>
      )}

      {/* Filter Bar */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 flex flex-wrap items-center justify-between gap-4">
        <div className="relative flex-1 min-w-[240px]">
          <Search className="w-4 h-4 text-slate-500 absolute left-3.5 top-3" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Cari nama mitra, email, atau no. telepon..."
            className="w-full bg-slate-950 border border-slate-800 rounded-lg pl-10 pr-4 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
          />
        </div>

        <div className="flex items-center gap-2">
          {(['PENDING', 'APPROVED', 'REJECTED', 'ALL'] as const).map((st) => (
            <button
              key={st}
              onClick={() => setFilterStatus(st)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
                filterStatus === st
                  ? 'bg-blue-600 text-white'
                  : 'bg-slate-950 text-slate-400 hover:text-white border border-slate-800'
              }`}
            >
              {st === 'PENDING'
                ? 'Menunggu Review'
                : st === 'APPROVED'
                ? 'Disetujui'
                : st === 'REJECTED'
                ? 'Ditolak'
                : 'Semua Status'}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Nama Mitra</th>
                <th className="py-3 px-4">Kontak & Keahlian</th>
                <th className="py-3 px-4">Waktu Submit</th>
                <th className="py-3 px-4">Status Verifikasi</th>
                <th className="py-3 px-4 text-right">Aksi Audit Dokumen</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800 text-slate-300">
              {isLoading ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-slate-400">
                    <div className="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                    <p className="text-xs">Memuat dokumen KYC dari database Supabase...</p>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-12 text-center text-slate-400">
                    <FileCheck className="w-8 h-8 mx-auto mb-2 text-slate-600" />
                    <p className="font-semibold text-sm text-slate-300">Tidak ada pengajuan verifikasi KYC</p>
                    <p className="text-xs text-slate-500 mt-1">
                      {searchTerm
                        ? 'Coba ubah kata kunci pencarian Anda.'
                        : 'Pengajuan dokumen KYC dari aplikasi Mitra Tukang akan muncul di sini secara real-time.'}
                    </p>
                  </td>
                </tr>
              ) : (
                filtered.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3.5 px-4">
                      <div className="font-semibold text-white">{item.tukangName}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{item.email}</div>
                    </td>
                    <td className="py-3.5 px-4">
                      <div className="font-medium text-slate-200">{item.category}</div>
                      <div className="text-[11px] text-slate-400 font-mono">{item.phone}</div>
                    </td>
                    <td className="py-3.5 px-4 font-mono text-[11px] text-slate-400">
                      {new Date(item.submittedAt).toLocaleString('id-ID')}
                    </td>
                    <td className="py-3.5 px-4">
                      {item.status === 'PENDING' && (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                          <Clock className="w-3.5 h-3.5" /> Menunggu Review
                        </span>
                      )}
                      {item.status === 'APPROVED' && (
                        <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                          <CheckCircle2 className="w-3.5 h-3.5" /> Disetujui (Approved)
                        </span>
                      )}
                      {item.status === 'REJECTED' && (
                        <div>
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-red-500/10 text-red-400 border border-red-500/20">
                            <XCircle className="w-3.5 h-3.5" /> Ditolak
                          </span>
                          {item.rejectionReason && (
                            <div className="text-[10px] text-red-300 mt-1 max-w-xs truncate">
                              {item.rejectionReason}
                            </div>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="py-3.5 px-4 text-right space-x-2">
                      <button
                        onClick={() => handleOpenPreview(item)}
                        className="px-2.5 py-1 bg-blue-600/20 hover:bg-blue-600 text-blue-300 hover:text-white rounded text-[11px] font-semibold border border-blue-500/30 transition-colors inline-flex items-center gap-1"
                      >
                        <Eye className="w-3 h-3" /> Periksa Berkas
                      </button>
                      {item.status === 'PENDING' && (
                        <>
                          <button
                            onClick={() => handleApprove(item)}
                            className="px-2.5 py-1 bg-emerald-600/20 hover:bg-emerald-600 text-emerald-300 hover:text-white rounded text-[11px] font-semibold border border-emerald-500/30 transition-colors"
                          >
                            Approve
                          </button>
                          <button
                            onClick={() => {
                              setRejectingItem(item);
                              setRejectionReasonInput('');
                            }}
                            className="px-2.5 py-1 bg-red-600/20 hover:bg-red-600 text-red-300 hover:text-white rounded text-[11px] font-semibold border border-red-500/30 transition-colors"
                          >
                            Reject
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal Preview Dokumen KTP & Selfie (Signed URL) */}
      {activeItem && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-3xl w-full p-6 space-y-5 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2">
                  <Shield className="w-5 h-5 text-blue-400" />
                  Audit Berkas KYC — {activeItem.tukangName}
                </h3>
                <div className="text-xs text-slate-400 mt-0.5">
                  Path Privat: {activeItem.ktpStoragePath} | Bucket: <code className="text-blue-300">kyc-private</code>
                </div>
              </div>
              <button
                onClick={() => setActiveItem(null)}
                className="text-slate-400 hover:text-white text-sm px-2 py-1"
              >
                ✕ Tutup
              </button>
            </div>

            {isGeneratingUrl ? (
              <div className="p-12 text-center text-slate-400 text-xs">
                Membuat Signed URL privat berumur pendek dari Supabase Storage...
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* 1. Foto KTP */}
                <div className="space-y-2">
                  <div className="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center justify-between">
                    <span>1. Foto KTP Asli</span>
                    {ktpSignedUrl && (
                      <a
                        href={ktpSignedUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="text-blue-400 hover:underline flex items-center gap-1 text-[11px]"
                      >
                        Buka Tab Baru <ExternalLink className="w-3 h-3" />
                      </a>
                    )}
                  </div>
                  <div className="bg-slate-950 border border-slate-800 rounded-xl h-56 flex flex-col items-center justify-center p-4 text-center overflow-hidden">
                    {ktpSignedUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={ktpSignedUrl}
                        alt="Foto KTP Mitra"
                        className="max-h-full object-contain rounded"
                      />
                    ) : (
                      <div className="space-y-1">
                        <FileCheck className="w-10 h-10 text-slate-600 mx-auto" />
                        <div className="text-xs text-slate-400 font-mono">
                          {activeItem.ktpStoragePath}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          (Privat: URL ditandatangani HMAC 3600 detik)
                        </div>
                      </div>
                    )}
                  </div>
                </div>

                {/* 2. Foto Selfie + KTP */}
                <div className="space-y-2">
                  <div className="text-xs font-semibold text-slate-300 uppercase tracking-wider flex items-center justify-between">
                    <span>2. Selfie Memegang KTP</span>
                    {selfieSignedUrl && (
                      <a
                        href={selfieSignedUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="text-blue-400 hover:underline flex items-center gap-1 text-[11px]"
                      >
                        Buka Tab Baru <ExternalLink className="w-3 h-3" />
                      </a>
                    )}
                  </div>
                  <div className="bg-slate-950 border border-slate-800 rounded-xl h-56 flex flex-col items-center justify-center p-4 text-center overflow-hidden">
                    {selfieSignedUrl ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img
                        src={selfieSignedUrl}
                        alt="Selfie KTP Mitra"
                        className="max-h-full object-contain rounded"
                      />
                    ) : (
                      <div className="space-y-1">
                        <FileCheck className="w-10 h-10 text-slate-600 mx-auto" />
                        <div className="text-xs text-slate-400 font-mono">
                          {activeItem.selfieStoragePath}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          (Privat: URL ditandatangani HMAC 3600 detik)
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            )}

            {/* Modal Actions */}
            <div className="flex items-center justify-between border-t border-slate-800 pt-4">
              <div className="text-xs text-slate-400">
                Status saat ini:{' '}
                <span className="font-semibold text-white">{activeItem.status}</span>
              </div>
              <div className="flex items-center gap-2">
                {activeItem.status === 'PENDING' && (
                  <>
                    <button
                      onClick={() => {
                        setRejectingItem(activeItem);
                        setRejectionReasonInput('');
                      }}
                      className="px-4 py-2 bg-red-600/20 hover:bg-red-600 text-red-300 hover:text-white rounded-xl text-xs font-semibold border border-red-500/30 transition-colors"
                    >
                      Tolak Pengajuan (Reject)
                    </button>
                    <button
                      onClick={() => handleApprove(activeItem)}
                      className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-semibold transition-colors"
                    >
                      Setujui Identitas (Approve)
                    </button>
                  </>
                )}
                <button
                  onClick={() => setActiveItem(null)}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-xl text-xs font-semibold transition-colors"
                >
                  Tutup
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modal Konfirmasi Penolakan KYC (Wajib Alasan - FR-032) */}
      {rejectingItem && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-red-500/10 border border-red-500/20 flex items-center justify-center shrink-0">
                <AlertCircle className="w-5 h-5 text-red-400" />
              </div>
              <div>
                <h3 className="text-sm font-bold text-white">
                  Tolak Verifikasi KYC — {rejectingItem.tukangName}
                </h3>
                <p className="text-xs text-slate-400">
                  Alasan ini akan dikirimkan langsung ke aplikasi tukang.
                </p>
              </div>
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">
                Alasan Penolakan (Wajib Diisi - FR-032)
              </label>
              <textarea
                value={rejectionReasonInput}
                onChange={(e) => setRejectionReasonInput(e.target.value)}
                placeholder="Contoh: Foto KTP buram, NIK terpotong, atau wajah pada selfie tertutup masker..."
                rows={4}
                className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-red-500"
              />
            </div>

            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setRejectingItem(null)}
                className="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-xs font-semibold"
              >
                Batal
              </button>
              <button
                onClick={handleConfirmReject}
                className="px-4 py-2 bg-red-600 hover:bg-red-500 text-white rounded-lg text-xs font-semibold"
              >
                Kirim Penolakan
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
