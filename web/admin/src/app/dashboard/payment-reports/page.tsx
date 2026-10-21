'use client';

import React, { useState, useEffect, useCallback } from 'react';
import {
  AlertTriangle,
  ShieldAlert,
  Search,
  CheckCircle2,
  UserX,
  ExternalLink,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface PaymentReport {
  id: string;
  job_id: string;
  reporter_id: string;
  reporter_name: string;
  reported_user_id: string;
  reported_user_name: string;
  reported_user_email?: string;
  category: 'PAYMENT_DEFAULT';
  is_priority: boolean;
  description: string;
  evidence_photos: string[];
  status: 'OPEN' | 'RESOLVED' | 'DISMISSED';
  created_at: string;
  admin_resolution_notes?: string;
}

interface SupabaseReportRow {
  id: string;
  job_id: string;
  reporter_id: string;
  reported_user_id: string;
  category: string;
  is_priority: boolean | null;
  description: string | null;
  evidence_photos: string[] | null;
  status: 'OPEN' | 'RESOLVED' | 'DISMISSED' | null;
  created_at: string;
  admin_resolution_notes: string | null;
}

export default function PaymentReportsPage() {
  const [reports, setReports] = useState<PaymentReport[]>([]);
  const [selectedReport, setSelectedReport] = useState<PaymentReport | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'OPEN' | 'RESOLVED'>('OPEN');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [isVonisModalOpen, setIsVonisModalOpen] = useState<boolean>(false);
  const [adminNotes, setAdminNotes] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState<boolean>(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const fetchReports = useCallback(async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('reports')
        .select(`
          id, job_id, reporter_id, reported_user_id, category, is_priority,
          description, evidence_photos, status, created_at, admin_resolution_notes
        `)
        .eq('category', 'PAYMENT_DEFAULT')
        .order('created_at', { ascending: false });

      if (!error && data) {
        const rows = data as unknown as SupabaseReportRow[];
        const mapped: PaymentReport[] = rows.map((d) => ({
          id: d.id,
          job_id: d.job_id,
          reporter_id: d.reporter_id,
          reporter_name: `Mitra Tukang (${d.reporter_id.slice(0, 6)})`,
          reported_user_id: d.reported_user_id,
          reported_user_name: `Pelanggan (${d.reported_user_id.slice(0, 6)})`,
          category: 'PAYMENT_DEFAULT',
          is_priority: d.is_priority ?? true,
          description: d.description || '',
          evidence_photos: d.evidence_photos || [],
          status: d.status || 'OPEN',
          created_at: d.created_at,
          admin_resolution_notes: d.admin_resolution_notes || undefined,
        }));
        setReports(mapped);
        setSelectedReport((prev) => {
          if (!prev || !mapped.some((m) => m.id === prev.id)) {
            return mapped[0] || null;
          }
          return prev;
        });
      }
    } catch {
      setReports([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchReports();
  }, [fetchReports]);

  const handleVonisSuspend = async () => {
    if (!selectedReport) return;
    if (adminNotes.trim().length < 5) {
      alert('Catatan investigasi Admin wajib diisi minimal 5 karakter.');
      return;
    }

    setIsSubmitting(true);
    try {
      const { error } = await supabase.rpc('rpc_admin_suspend_payment_defaulter', {
        p_report_id: selectedReport.id,
        p_admin_notes: adminNotes.trim(),
      });

      if (!error) {
        setSuccessMessage(
          `VONIS RESMI DIBERIKAN: Akun Pelanggan ${selectedReport.reported_user_name} berhasil di-suspend permanen tanpa toleransi 3x sesuai aturan BR-67.`
        );
        setIsVonisModalOpen(false);
        setAdminNotes('');
        setReports((prev) =>
          prev.map((r) =>
            r.id === selectedReport.id
              ? {
                  ...r,
                  status: 'RESOLVED',
                  admin_resolution_notes: adminNotes.trim(),
                }
              : r
          )
        );
        setSelectedReport((prev) =>
          prev ? { ...prev, status: 'RESOLVED', admin_resolution_notes: adminNotes.trim() } : null
        );
      } else {
        alert(`Gagal memberikan vonis: ${error.message}`);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      alert(`Terjadi kesalahan: ${msg}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const filteredReports = reports.filter((r) => {
    if (filterStatus !== 'ALL' && r.status !== filterStatus) return false;
    if (searchQuery.trim() !== '') {
      const query = searchQuery.toLowerCase();
      return (
        r.description.toLowerCase().includes(query) ||
        r.reporter_name.toLowerCase().includes(query) ||
        r.reported_user_name.toLowerCase().includes(query)
      );
    }
    return true;
  });

  return (
    <div className="p-8 space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold tracking-tight text-white">
              Investigasi Masalah Pembayaran (BR-67)
            </h1>
            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-500/10 text-rose-400 border border-rose-500/20">
              Antrean Prioritas
            </span>
          </div>
          <p className="text-slate-400 text-sm mt-1">
            Laporan wanprestasi ketika Pelanggan menolak membayar / membayar kurang. Terbukti bersalah langsung
            di-suspend permanen tanpa toleransi 3x.
          </p>
        </div>
      </div>

      {successMessage && (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-emerald-400 text-sm flex items-center justify-between">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 shrink-0" />
            <span>{successMessage}</span>
          </div>
          <button
            onClick={() => setSuccessMessage(null)}
            className="text-xs underline hover:text-emerald-300 ml-4"
          >
            Tutup
          </button>
        </div>
      )}

      {/* Filter Bar */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-slate-900 border border-slate-800 p-3 rounded-xl">
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <button
            onClick={() => setFilterStatus('OPEN')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              filterStatus === 'OPEN'
                ? 'bg-rose-600 text-white shadow-lg shadow-rose-600/20'
                : 'text-slate-400 hover:text-white bg-slate-800/60'
            }`}
          >
            Menunggu Investigasi ({reports.filter((r) => r.status === 'OPEN').length})
          </button>
          <button
            onClick={() => setFilterStatus('RESOLVED')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              filterStatus === 'RESOLVED'
                ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/20'
                : 'text-slate-400 hover:text-white bg-slate-800/60'
            }`}
          >
            Selesai / Vonis Suspend ({reports.filter((r) => r.status === 'RESOLVED').length})
          </button>
          <button
            onClick={() => setFilterStatus('ALL')}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors ${
              filterStatus === 'ALL'
                ? 'bg-blue-600 text-white'
                : 'text-slate-400 hover:text-white bg-slate-800/60'
            }`}
          >
            Semua ({reports.length})
          </button>
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-500" />
          <input
            type="text"
            placeholder="Cari pelapor / deskripsi..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-slate-950 border border-slate-800 rounded-lg pl-9 pr-3 py-1.5 text-xs text-white focus:outline-none focus:border-blue-500"
          />
        </div>
      </div>

      {/* Master Detail View */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Reports List */}
        <div className="lg:col-span-5 space-y-3">
          {isLoading ? (
            <div className="p-8 text-center bg-slate-900 border border-slate-800 rounded-xl text-slate-500 text-sm flex flex-col items-center justify-center gap-2">
              <div className="w-6 h-6 border-2 border-rose-500 border-t-transparent rounded-full animate-spin" />
              <span>Memuat data laporan pembayaran...</span>
            </div>
          ) : filteredReports.length === 0 ? (
            <div className="p-8 text-center bg-slate-900 border border-slate-800 rounded-xl text-slate-500 text-sm">
              Tidak ada laporan dalam kategori ini.
            </div>
          ) : (
            filteredReports.map((report) => {
              const isSelected = selectedReport?.id === report.id;
              return (
                <div
                  key={report.id}
                  onClick={() => setSelectedReport(report)}
                  className={`p-4 rounded-xl border transition-all cursor-pointer ${
                    isSelected
                      ? 'bg-slate-800/90 border-rose-500 ring-1 ring-rose-500/40'
                      : 'bg-slate-900 border-slate-800 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <span className="text-[10px] font-bold px-2 py-0.5 rounded bg-rose-500/10 text-rose-400 border border-rose-500/20">
                        BR-67 PRIORITAS
                      </span>
                      <h4 className="font-semibold text-sm text-white mt-1.5">{report.reporter_name}</h4>
                      <p className="text-xs text-slate-400">Terlapor: {report.reported_user_name}</p>
                    </div>
                    <span
                      className={`text-[11px] font-semibold px-2 py-0.5 rounded border ${
                        report.status === 'OPEN'
                          ? 'bg-amber-500/10 text-amber-400 border-amber-500/20'
                          : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                      }`}
                    >
                      {report.status}
                    </span>
                  </div>

                  <p className="text-xs text-slate-300 mt-2 line-clamp-2">{report.description}</p>

                  <div className="flex items-center justify-between text-[11px] text-slate-500 mt-3 pt-2.5 border-t border-slate-800/80">
                    <span>Lampiran: {report.evidence_photos.length} Foto</span>
                    <span>{new Date(report.created_at).toLocaleDateString()}</span>
                  </div>
                </div>
              );
            })
          )}
        </div>

        {/* Selected Report Details & Action Desk */}
        <div className="lg:col-span-7 bg-slate-900 border border-slate-800 rounded-2xl p-6 flex flex-col justify-between min-h-[560px]">
          {selectedReport ? (
            <div className="space-y-6">
              {/* Header Box */}
              <div className="flex items-start justify-between border-b border-slate-800 pb-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold px-2.5 py-1 rounded bg-rose-500/20 text-rose-300 border border-rose-500/30">
                      LAPORAN #{selectedReport.id}
                    </span>
                    <span className="text-xs text-slate-500">Job ID: {selectedReport.job_id}</span>
                  </div>
                  <h3 className="text-lg font-bold text-white mt-2">
                    Pelapor: {selectedReport.reporter_name}
                  </h3>
                  <p className="text-xs text-slate-400">
                    Melaporkan Pelanggan: <strong className="text-slate-200">{selectedReport.reported_user_name}</strong>
                  </p>
                </div>

                <div className="text-right">
                  <div className="text-xs text-slate-500">Waktu Lapor</div>
                  <div className="text-xs font-semibold text-slate-300">
                    {new Date(selectedReport.created_at).toLocaleString()}
                  </div>
                </div>
              </div>

              {/* Kronologi */}
              <div>
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  Kronologi Kendala Pembayaran
                </h4>
                <div className="p-4 bg-slate-950 border border-slate-800 rounded-xl text-xs text-slate-200 leading-relaxed">
                  {selectedReport.description}
                </div>
              </div>

              {/* Foto Bukti Hasil Kerja & Bukti Pendukung */}
              <div>
                <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
                  Foto Bukti Fisik Hasil Kerja & Dokumen Pendukung ({selectedReport.evidence_photos.length})
                </h4>
                {selectedReport.evidence_photos.length === 0 ? (
                  <p className="text-xs text-slate-500 italic">Tidak ada foto terlampir.</p>
                ) : (
                  <div className="grid grid-cols-3 gap-3">
                    {selectedReport.evidence_photos.map((url, i) => (
                      <a
                        key={i}
                        href={url}
                        target="_blank"
                        rel="noreferrer"
                        className="group relative h-28 bg-slate-950 rounded-lg overflow-hidden border border-slate-800 hover:border-blue-500 transition-all flex items-center justify-center"
                      >
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={url}
                          alt={`Bukti ${i + 1}`}
                          className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                        />
                        <div className="absolute inset-0 bg-slate-950/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-white text-xs gap-1">
                          <ExternalLink className="w-3.5 h-3.5" /> Lihat
                        </div>
                      </a>
                    ))}
                  </div>
                )}
              </div>

              {/* Resolusi / Catatan Vonis Admin */}
              {selectedReport.admin_resolution_notes && (
                <div className="p-4 bg-emerald-500/10 border border-emerald-500/20 rounded-xl">
                  <div className="flex items-center gap-2 text-xs font-bold text-emerald-400 mb-1">
                    <CheckCircle2 className="w-4 h-4" />
                    Catatan Vonis Resmi Admin Beres
                  </div>
                  <p className="text-xs text-slate-300 leading-relaxed">
                    {selectedReport.admin_resolution_notes}
                  </p>
                </div>
              )}

              {/* Rule Banner */}
              <div className="p-3.5 bg-rose-500/10 border border-rose-500/20 rounded-xl text-xs text-rose-300 leading-relaxed flex items-start gap-2.5">
                <ShieldAlert className="w-4 h-4 shrink-0 text-rose-400 mt-0.5" />
                <div>
                  <strong>Ketentuan Golden Rule BR-67:</strong> Admin berwenang mengaudit Chat, Nota Sah, dan Foto
                  Hasil Kerja. Jika Pelanggan terbukti wanprestasi / menolak bayar, akun Pelanggan langsung
                  dikenakan <strong>Suspend Permanen</strong> tanpa pemakluman 3x. Banding hanya melalui Email
                  Resmi Perusahaan.
                </div>
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center flex-1 text-slate-500 text-sm">
              <AlertTriangle className="w-12 h-12 text-slate-700 mb-3" />
              Pilih laporan di sebelah kiri untuk melihat investigasi audit.
            </div>
          )}

          {/* Action Footer */}
          {selectedReport && selectedReport.status === 'OPEN' && (
            <div className="pt-6 border-t border-slate-800 flex items-center justify-end gap-3 mt-6">
              <button
                onClick={() => setIsVonisModalOpen(true)}
                className="px-4 py-2.5 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-bold transition-all shadow-lg shadow-rose-600/30 flex items-center gap-2"
              >
                <UserX className="w-4 h-4" />
                Vonis Suspend Permanen Pelanggan (BR-67)
              </button>
            </div>
          )}
        </div>
      </div>

      {/* Modal Vonis Suspend Permanen */}
      {isVonisModalOpen && selectedReport && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <div className="flex items-center gap-3 text-rose-400">
              <ShieldAlert className="w-6 h-6 shrink-0" />
              <h3 className="text-lg font-bold text-white">Vonis Pelanggan Wanprestasi (BR-67)</h3>
            </div>

            <p className="text-xs text-slate-300 leading-relaxed">
              Anda akan memberikan vonis resmi terhadap <strong>{selectedReport.reported_user_name}</strong>.
              Akun pelanggan akan langsung diubah menjadi <strong>MANUAL_PERMANENT (Ditolak Login)</strong> tanpa
              pemakluman 3x. Ikatan job tukang akan diselesaikan dan dicatat ke dalam audit log.
            </p>

            <div>
              <label className="text-xs font-semibold text-slate-400 block mb-1">
                Catatan Investigasi Admin (Wajib)*
              </label>
              <textarea
                rows={4}
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="Contoh: Bukti fisik pekerjaan terverifikasi sesuai Nota Sah #1. Pelanggan menolak membayar tunai/transfer..."
                className="w-full bg-slate-950 border border-slate-800 rounded-lg p-3 text-xs text-white focus:outline-none focus:border-rose-500"
              />
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                onClick={() => setIsVonisModalOpen(false)}
                disabled={isSubmitting}
                className="px-4 py-2 text-xs font-medium text-slate-400 hover:text-white"
              >
                Batal
              </button>
              <button
                onClick={handleVonisSuspend}
                disabled={isSubmitting}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-lg text-xs font-bold transition-all disabled:opacity-50 flex items-center gap-2"
              >
                {isSubmitting ? 'Memproses...' : 'Terapkan Suspend Permanen'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
