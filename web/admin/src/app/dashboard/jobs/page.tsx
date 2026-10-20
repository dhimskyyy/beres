'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import {
  Briefcase,
  Search,
  RefreshCw,
  Clock,
  MapPin,
  FileText,
  MessageSquare,
  Receipt,
  Image as ImageIcon,
  AlertTriangle,
  X,
  Star,
} from 'lucide-react';

interface JobItem {
  id: string;
  user_id: string;
  category_id: string;
  description: string;
  area_label: string;
  address_full: string;
  status: string;
  locked_tukang_id: string | null;
  created_at: string;
  expires_at: string;
  categories?: { name: string } | null;
  profiles?: { full_name: string } | null;
}

interface AuditJobInfo {
  id?: string;
  status?: string;
  description?: string;
  area_label?: string;
  address_full?: string;
  created_at?: string;
  category_name?: string;
  user_name?: string;
  user_email?: string;
  user_phone?: string;
  tukang_name?: string;
  tukang_email?: string;
  tukang_phone?: string;
  [key: string]: unknown;
}

interface AuditDetails {
  job: AuditJobInfo;
  status_history: Array<{
    id: string;
    from_status: string;
    to_status: string;
    actor_id?: string;
    actor_name?: string;
    actor_role?: string;
    notes?: string;
    created_at: string;
  }>;
  chat_messages: Array<{
    id: string;
    sender_name?: string;
    sender_role?: string;
    message_type: string;
    content: string;
    image_url?: string;
    created_at: string;
  }>;
  notas: Array<{
    id: string;
    version: number;
    status: string;
    items: Array<{ name: string; qty: number; unit_price: number; total_price: number }>;
    total_amount: number;
    payment_method: string;
    note?: string;
    previous_approved_total?: number;
    created_at: string;
    responded_at?: string;
  }>;
  photos: Array<{
    id: string;
    photo_type: string;
    photo_url: string;
    created_at: string;
  }>;
  cancel_requests: Array<{
    id: string;
    requester_role: string;
    status: string;
    status_before_cancel: string;
    reason_category?: string;
    reason_text?: string;
    admin_notes?: string;
    distance_to_job_m?: number;
    submitted_at?: string;
    resolved_at?: string;
    resolved_by_name?: string;
  }>;
  reports: Array<{
    id: string;
    category: string;
    is_priority: boolean;
    description: string;
    status: string;
    admin_resolution_notes?: string;
    created_at: string;
    reporter_name?: string;
  }>;
  review?: {
    rating: number;
    comment?: string;
    created_at: string;
  } | null;
  audit_logs: Array<{
    id: number;
    action: string;
    target_type: string;
    metadata?: Record<string, unknown>;
    created_at: string;
  }>;
}

const JOB_STATUSES = [
  'ALL',
  'OPEN',
  'NEGOTIATING',
  'NOTA_APPROVED',
  'ON_THE_WAY',
  'ARRIVED',
  'WORKING',
  'COMPLETED',
  'CANCELLED',
  'EXPIRED',
  'CANCEL_PENDING',
];

export default function AdminJobsPage() {
  const [jobs, setJobs] = useState<JobItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedStatus, setSelectedStatus] = useState<string>('ALL');
  const [searchQuery, setSearchQuery] = useState<string>('');

  // State untuk Audit Detail Modal (FR-031)
  const [selectedJobId, setSelectedJobId] = useState<string | null>(null);
  const [auditDetails, setAuditDetails] = useState<AuditDetails | null>(null);
  const [loadingAudit, setLoadingAudit] = useState<boolean>(false);
  const [activeTab, setActiveTab] = useState<'timeline' | 'chat' | 'notas' | 'photos' | 'disputes'>('timeline');

  const fetchJobs = useCallback(async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('jobs')
        .select(`
          id,
          user_id,
          category_id,
          description,
          area_label,
          address_full,
          status,
          locked_tukang_id,
          created_at,
          expires_at,
          categories (name),
          profiles:user_id (full_name)
        `)
        .order('created_at', { ascending: false });

      if (selectedStatus !== 'ALL') {
        query = query.eq('status', selectedStatus);
      }

      const { data, error } = await query;
      if (error) throw error;
      setJobs((data as unknown as JobItem[]) || []);
    } catch (err) {
      console.error('Gagal mengambil data jobs:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedStatus]);

  useEffect(() => {
    fetchJobs();
  }, [fetchJobs]);

  const openAuditDetails = async (jobId: string) => {
    setSelectedJobId(jobId);
    setLoadingAudit(true);
    setActiveTab('timeline');

    try {
      const { data, error } = await supabase.rpc('rpc_admin_get_job_audit_details', {
        p_job_id: jobId,
      });

      if (error) throw error;
      setAuditDetails(data as AuditDetails);
    } catch (err) {
      console.error('Gagal mengambil detail audit:', err);
      alert('Gagal mengambil detail audit pekerjaan.');
      setSelectedJobId(null);
    } finally {
      setLoadingAudit(false);
    }
  };

  const filteredJobs = jobs.filter((job) => {
    const q = searchQuery.toLowerCase();
    const desc = job.description?.toLowerCase() || '';
    const area = job.area_label?.toLowerCase() || '';
    const cat = job.categories?.name?.toLowerCase() || '';
    return desc.includes(q) || area.includes(q) || cat.includes(q);
  });

  const getStatusBadge = (status: string) => {
    const map: Record<string, { bg: string; text: string }> = {
      OPEN: { bg: 'bg-blue-500/10 border-blue-500/30', text: 'text-blue-400' },
      NEGOTIATING: { bg: 'bg-amber-500/10 border-amber-500/30', text: 'text-amber-400' },
      NOTA_APPROVED: { bg: 'bg-purple-500/10 border-purple-500/30', text: 'text-purple-400' },
      ON_THE_WAY: { bg: 'bg-cyan-500/10 border-cyan-500/30', text: 'text-cyan-400' },
      ARRIVED: { bg: 'bg-indigo-500/10 border-indigo-500/30', text: 'text-indigo-400' },
      WORKING: { bg: 'bg-orange-500/10 border-orange-500/30', text: 'text-orange-400' },
      COMPLETED: { bg: 'bg-emerald-500/10 border-emerald-500/30', text: 'text-emerald-400' },
      CANCELLED: { bg: 'bg-slate-500/10 border-slate-500/30', text: 'text-slate-400' },
      EXPIRED: { bg: 'bg-zinc-500/10 border-zinc-500/30', text: 'text-zinc-400' },
      CANCEL_PENDING: { bg: 'bg-red-500/10 border-red-500/30', text: 'text-red-400' },
    };
    const c = map[status] || { bg: 'bg-slate-500/10 border-slate-500/30', text: 'text-slate-400' };
    return (
      <span
        className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border tracking-wider ${c.bg} ${c.text}`}
      >
        {status}
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl font-bold tracking-tight text-white flex items-center gap-2">
            <Briefcase className="w-5 h-5 text-blue-400" /> Pengawasan 10 Status Pekerjaan
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Audit menyeluruh siklus hidup pekerjaan, transparansi chat & nota, verifikasi foto hasil kerja, dan pelacakan sengketa (FR-031).
          </p>
        </div>
        <button
          onClick={fetchJobs}
          className="flex items-center gap-1.5 px-3 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-lg border border-slate-700 transition-colors"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
          Segarkan Data
        </button>
      </div>

      {/* Filter Status & Search */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
        <div className="flex items-center gap-2 overflow-x-auto pb-1 max-w-2xl no-scrollbar">
          {JOB_STATUSES.map((status) => (
            <button
              key={status}
              onClick={() => setSelectedStatus(status)}
              className={`px-2.5 py-1 text-xs rounded-lg font-medium whitespace-nowrap transition-colors ${
                selectedStatus === status
                  ? 'bg-blue-600 text-white'
                  : 'bg-slate-900 text-slate-400 hover:bg-slate-800 hover:text-slate-200 border border-slate-800'
              }`}
            >
              {status}
            </button>
          ))}
        </div>

        <div className="relative min-w-[220px]">
          <Search className="w-4 h-4 text-slate-500 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Cari deskripsi, lokasi, kategori..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 bg-slate-900 border border-slate-800 text-slate-200 text-xs rounded-lg focus:outline-none focus:border-blue-500 placeholder-slate-500"
          />
        </div>
      </div>

      {/* Table Pekerjaan */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
              <tr>
                <th className="py-3 px-4">Kategori & Waktu</th>
                <th className="py-3 px-4">Deskripsi Tugas</th>
                <th className="py-3 px-4">Area & Alamat</th>
                <th className="py-3 px-4">Pelanggan</th>
                <th className="py-3 px-4">Status Pekerjaan</th>
                <th className="py-3 px-4">Tukang Terpilih</th>
                <th className="py-3 px-4 text-right">Audit</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 text-slate-300">
              {loading ? (
                <tr>
                  <td colSpan={7} className="text-center py-10 text-slate-500">
                    Memuat data pekerjaan...
                  </td>
                </tr>
              ) : filteredJobs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-10 text-slate-500">
                    Tidak ada pekerjaan ditemukan untuk kriteria ini.
                  </td>
                </tr>
              ) : (
                filteredJobs.map((job) => (
                  <tr key={job.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3 px-4">
                      <div className="font-bold text-white">
                        {job.categories?.name || 'Umum'}
                      </div>
                      <div className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5">
                        <Clock className="w-3 h-3" />
                        {new Date(job.created_at).toLocaleString('id-ID', {
                          day: '2-digit',
                          month: 'short',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </div>
                    </td>
                    <td className="py-3 px-4 max-w-xs">
                      <div className="truncate font-medium text-slate-200">
                        {job.description}
                      </div>
                      <div className="text-[10px] text-slate-500 font-mono mt-0.5">
                        ID: {job.id.slice(0, 8)}...
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="font-semibold text-slate-200 flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-blue-400" />
                        {job.area_label}
                      </div>
                      <div className="text-[11px] text-slate-500 truncate max-w-[200px] mt-0.5">
                        {job.address_full}
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5">
                        <div className="w-5 h-5 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-[10px]">
                          {job.profiles?.full_name ? job.profiles.full_name[0] : 'U'}
                        </div>
                        <span className="font-medium text-slate-200">
                          {job.profiles?.full_name || 'Pelanggan'}
                        </span>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      {getStatusBadge(job.status)}
                    </td>
                    <td className="py-3 px-4">
                      {job.locked_tukang_id ? (
                        <span className="text-[11px] font-mono text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                          {job.locked_tukang_id.slice(0, 8)}...
                        </span>
                      ) : (
                        <span className="text-slate-500 text-[11px] italic">
                          Belum di-lock
                        </span>
                      )}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={() => openAuditDetails(job.id)}
                        className="px-2.5 py-1 bg-blue-600/20 hover:bg-blue-600 text-blue-300 hover:text-white rounded text-[11px] font-semibold border border-blue-500/30 transition-colors flex items-center gap-1 ml-auto"
                      >
                        <FileText className="w-3.5 h-3.5" />
                        Audit Lengkap
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* MODAL AUDIT LENGKAP (FR-031) */}
      {selectedJobId && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-3 sm:p-5">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-4xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden">
            {/* Modal Header */}
            <div className="p-4 sm:p-5 bg-slate-950 border-b border-slate-800 flex items-center justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-bold text-white text-base">Audit Forensik Pekerjaan</span>
                  {auditDetails?.job?.status && getStatusBadge(auditDetails.job.status)}
                </div>
                <div className="text-xs text-slate-400 font-mono mt-0.5">
                  Job ID: {selectedJobId}
                </div>
              </div>
              <button
                onClick={() => setSelectedJobId(null)}
                className="text-slate-400 hover:text-white p-1"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {loadingAudit ? (
              <div className="flex-1 flex items-center justify-center py-20 text-slate-400 text-sm">
                Mengambil data forensik dari database...
              </div>
            ) : auditDetails ? (
              <>
                {/* Ringkasan Pihak */}
                <div className="p-4 bg-slate-950/40 border-b border-slate-800 grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                  <div className="bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                    <span className="text-[10px] uppercase font-bold text-blue-400 tracking-wider">
                      Pelanggan (User)
                    </span>
                    <div className="font-bold text-white mt-1">{auditDetails.job.user_name || 'Tanpa Nama'}</div>
                    <div className="text-slate-400">{auditDetails.job.user_email} • {auditDetails.job.user_phone}</div>
                  </div>
                  <div className="bg-slate-900/80 p-3 rounded-lg border border-slate-800">
                    <span className="text-[10px] uppercase font-bold text-orange-400 tracking-wider">
                      Mitra Tukang
                    </span>
                    <div className="font-bold text-white mt-1">{auditDetails.job.tukang_name || 'Belum Ditugaskan'}</div>
                    <div className="text-slate-400">{auditDetails.job.tukang_email || '-'} • {auditDetails.job.tukang_phone || '-'}</div>
                  </div>
                </div>

                {/* Tabs */}
                <div className="flex items-center gap-2 px-5 pt-3 border-b border-slate-800 bg-slate-900/50">
                  <button
                    onClick={() => setActiveTab('timeline')}
                    className={`pb-2.5 text-xs font-semibold flex items-center gap-1.5 transition-colors border-b-2 ${
                      activeTab === 'timeline'
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <Clock className="w-3.5 h-3.5" /> Timeline 10 Status ({auditDetails.status_history.length})
                  </button>
                  <button
                    onClick={() => setActiveTab('chat')}
                    className={`pb-2.5 text-xs font-semibold flex items-center gap-1.5 transition-colors border-b-2 ${
                      activeTab === 'chat'
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <MessageSquare className="w-3.5 h-3.5" /> Histori Chat ({auditDetails.chat_messages.length})
                  </button>
                  <button
                    onClick={() => setActiveTab('notas')}
                    className={`pb-2.5 text-xs font-semibold flex items-center gap-1.5 transition-colors border-b-2 ${
                      activeTab === 'notas'
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <Receipt className="w-3.5 h-3.5" /> Versi Nota & Revisi ({auditDetails.notas.length})
                  </button>
                  <button
                    onClick={() => setActiveTab('photos')}
                    className={`pb-2.5 text-xs font-semibold flex items-center gap-1.5 transition-colors border-b-2 ${
                      activeTab === 'photos'
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <ImageIcon className="w-3.5 h-3.5" /> Foto Bukti ({auditDetails.photos.length})
                  </button>
                  <button
                    onClick={() => setActiveTab('disputes')}
                    className={`pb-2.5 text-xs font-semibold flex items-center gap-1.5 transition-colors border-b-2 ${
                      activeTab === 'disputes'
                        ? 'border-blue-500 text-blue-400'
                        : 'border-transparent text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    <AlertTriangle className="w-3.5 h-3.5" /> Batal & Sengketa ({auditDetails.cancel_requests.length + auditDetails.reports.length})
                  </button>
                </div>

                {/* Tab Content */}
                <div className="flex-1 p-5 overflow-y-auto space-y-4 text-xs">
                  {/* TAB 1: TIMELINE 10 STATUS */}
                  {activeTab === 'timeline' && (
                    <div className="space-y-3">
                      {auditDetails.status_history.length === 0 ? (
                        <div className="text-center py-8 text-slate-500">Belum ada transisi status tercatat.</div>
                      ) : (
                        auditDetails.status_history.map((sh, idx) => (
                          <div key={sh.id} className="flex items-start gap-3 bg-slate-950 p-3 rounded-lg border border-slate-800">
                            <div className="w-6 h-6 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold text-[11px] shrink-0 mt-0.5">
                              {idx + 1}
                            </div>
                            <div className="flex-1 space-y-1">
                              <div className="flex items-center justify-between">
                                <div className="font-semibold text-white">
                                  {sh.from_status ? `${sh.from_status} → ` : ''}
                                  <span className="text-blue-400">{sh.to_status}</span>
                                </div>
                                <span className="text-[10px] text-slate-400 font-mono">
                                  {new Date(sh.created_at).toLocaleString('id-ID')}
                                </span>
                              </div>
                              <div className="text-slate-400">
                                Aktor: <span className="text-slate-200">{sh.actor_name || 'Sistem Otomatis'}</span> ({sh.actor_role || 'SYSTEM'})
                              </div>
                              {sh.notes && (
                                <div className="text-slate-300 italic bg-slate-900 p-2 rounded border border-slate-800/80">
                                  &quot;{sh.notes}&quot;
                                </div>
                              )}
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  )}

                  {/* TAB 2: CHAT MESSAGES */}
                  {activeTab === 'chat' && (
                    <div className="space-y-2.5">
                      {auditDetails.chat_messages.length === 0 ? (
                        <div className="text-center py-8 text-slate-500">Tidak ada percakapan tercatat.</div>
                      ) : (
                        auditDetails.chat_messages.map((msg) => (
                          <div
                            key={msg.id}
                            className={`p-3 rounded-lg border text-xs ${
                              msg.message_type === 'SYSTEM_EVENT'
                                ? 'bg-slate-950 border-slate-800 text-slate-400 text-center italic'
                                : msg.sender_role === 'USER'
                                ? 'bg-blue-950/20 border-blue-900/40 text-slate-200'
                                : 'bg-orange-950/20 border-orange-900/40 text-slate-200'
                            }`}
                          >
                            <div className="flex items-center justify-between mb-1 text-[11px]">
                              <span className="font-bold text-white">
                                {msg.sender_name || 'Sistem'} ({msg.sender_role || 'SYSTEM'})
                              </span>
                              <span className="text-[10px] text-slate-500 font-mono">
                                {new Date(msg.created_at).toLocaleTimeString('id-ID')}
                              </span>
                            </div>
                            <div className="text-slate-300">{msg.content}</div>
                            {msg.image_url && (
                              <div className="mt-2">
                                <a
                                  href={msg.image_url}
                                  target="_blank"
                                  rel="noopener noreferrer"
                                  className="text-blue-400 hover:underline"
                                >
                                  [Lihat Lampiran Gambar]
                                </a>
                              </div>
                            )}
                          </div>
                        ))
                      )}
                    </div>
                  )}

                  {/* TAB 3: NOTAS & REVISIONS */}
                  {activeTab === 'notas' && (
                    <div className="space-y-4">
                      {auditDetails.notas.length === 0 ? (
                        <div className="text-center py-8 text-slate-500">Belum ada Nota dibuat.</div>
                      ) : (
                        auditDetails.notas.map((nota) => (
                          <div key={nota.id} className="p-4 bg-slate-950 rounded-xl border border-slate-800 space-y-3">
                            <div className="flex items-center justify-between">
                              <span className="font-bold text-white text-sm">
                                Nota Versi #{nota.version} {nota.version > 1 ? '(Revisi)' : '(Awal)'}
                              </span>
                              <span
                                className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                                  nota.status === 'APPROVED'
                                    ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                                    : nota.status === 'SUPERSEDED' || nota.status === 'VOID'
                                    ? 'bg-slate-800 text-slate-400'
                                    : 'bg-amber-500/20 text-amber-400'
                                }`}
                              >
                                {nota.status}
                              </span>
                            </div>

                            <table className="w-full text-left">
                              <thead className="text-slate-400 border-b border-slate-800">
                                <tr>
                                  <th className="py-1">Uraian Pekerjaan / Material</th>
                                  <th className="py-1 text-center">Vol</th>
                                  <th className="py-1 text-right">Harga Satuan</th>
                                  <th className="py-1 text-right">Subtotal</th>
                                </tr>
                              </thead>
                              <tbody className="divide-y divide-slate-800/60">
                                {(nota.items || []).map((it, idx) => (
                                  <tr key={idx}>
                                    <td className="py-1.5 text-slate-200">{it.name}</td>
                                    <td className="py-1.5 text-center text-slate-400">{it.qty}</td>
                                    <td className="py-1.5 text-right text-slate-400">
                                      Rp {Number(it.unit_price).toLocaleString('id-ID')}
                                    </td>
                                    <td className="py-1.5 text-right font-semibold text-white">
                                      Rp {Number(it.total_price).toLocaleString('id-ID')}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>

                            <div className="pt-2 border-t border-slate-800 flex justify-between items-center text-xs">
                              <div className="text-slate-400">
                                Metode Bayar: <span className="font-bold text-white">{nota.payment_method}</span>
                                {nota.previous_approved_total && (
                                  <span className="ml-2 text-amber-400">
                                    (Harga Awal: Rp {Number(nota.previous_approved_total).toLocaleString('id-ID')})
                                  </span>
                                )}
                              </div>
                              <div className="text-sm font-bold text-emerald-400">
                                Total: Rp {Number(nota.total_amount).toLocaleString('id-ID')}
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  )}

                  {/* TAB 4: PHOTOS */}
                  {activeTab === 'photos' && (
                    <div>
                      {auditDetails.photos.length === 0 ? (
                        <div className="text-center py-8 text-slate-500">Tidak ada foto diunggah pada pekerjaan ini.</div>
                      ) : (
                        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                          {auditDetails.photos.map((ph) => (
                            <div key={ph.id} className="bg-slate-950 p-2 rounded-lg border border-slate-800 space-y-1.5">
                              <div className="h-32 bg-slate-900 rounded overflow-hidden flex items-center justify-center">
                                <a href={ph.photo_url} target="_blank" rel="noopener noreferrer">
                                  {/* eslint-disable-next-line @next/next/no-img-element */}
                                  <img
                                    src={ph.photo_url}
                                    alt={ph.photo_type}
                                    className="w-full h-full object-cover hover:scale-105 transition-transform"
                                  />
                                </a>
                              </div>
                              <div className="flex items-center justify-between text-[10px]">
                                <span className="font-bold text-blue-400">{ph.photo_type}</span>
                                <span className="text-slate-500">{new Date(ph.created_at).toLocaleDateString('id-ID')}</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}

                  {/* TAB 5: DISPUTES & CANCELLATION */}
                  {activeTab === 'disputes' && (
                    <div className="space-y-4">
                      {/* Cancel Requests */}
                      <div>
                        <h4 className="font-bold text-white mb-2 text-xs uppercase tracking-wider text-slate-400">
                          Pengajuan Pembatalan (BR-50 s/d BR-56)
                        </h4>
                        {auditDetails.cancel_requests.length === 0 ? (
                          <div className="text-slate-500 italic py-2">Tidak ada permohonan pembatalan.</div>
                        ) : (
                          auditDetails.cancel_requests.map((cr) => (
                            <div key={cr.id} className="p-3 bg-slate-950 rounded-lg border border-slate-800 space-y-1 mb-2">
                              <div className="flex items-center justify-between">
                                <span className="font-bold text-white">
                                  Pemohon: {cr.requester_role} (Status Saat Batal: {cr.status_before_cancel})
                                </span>
                                <span className="font-bold text-amber-400">{cr.status}</span>
                              </div>
                              <div className="text-slate-300">
                                Kategori: <span className="font-semibold">{cr.reason_category}</span> — &quot;{cr.reason_text}&quot;
                              </div>
                              {cr.admin_notes && (
                                <div className="text-amber-300/80 italic">
                                  Catatan Khusus Admin: {cr.admin_notes}
                                </div>
                              )}
                              {cr.distance_to_job_m !== null && cr.distance_to_job_m !== undefined && (
                                <div className="text-slate-500 text-[11px]">
                                  Jarak Tukang ke Job saat Batal: {Math.round(cr.distance_to_job_m)} meter
                                </div>
                              )}
                            </div>
                          ))
                        )}
                      </div>

                      {/* Dispute Reports */}
                      <div className="pt-3 border-t border-slate-800">
                        <h4 className="font-bold text-white mb-2 text-xs uppercase tracking-wider text-slate-400">
                          Laporan Masalah Pembayaran & Sengketa (BR-67)
                        </h4>
                        {auditDetails.reports.length === 0 ? (
                          <div className="text-slate-500 italic py-2">Tidak ada laporan sengketa aktif.</div>
                        ) : (
                          auditDetails.reports.map((rep) => (
                            <div key={rep.id} className="p-3 bg-red-950/20 border border-red-500/30 rounded-lg space-y-1">
                              <div className="flex items-center justify-between">
                                <span className="font-bold text-red-400">[{rep.category}] Prioritas: {rep.is_priority ? 'YA' : 'TIDAK'}</span>
                                <span className="font-mono text-slate-400">{rep.status}</span>
                              </div>
                              <div className="text-slate-200">&quot;{rep.description}&quot;</div>
                              {rep.admin_resolution_notes && (
                                <div className="text-emerald-400 font-semibold pt-1">
                                  Resolusi Admin: {rep.admin_resolution_notes}
                                </div>
                              )}
                            </div>
                          ))
                        )}
                      </div>

                      {/* Customer Review */}
                      {auditDetails.review && (
                        <div className="pt-3 border-t border-slate-800">
                          <h4 className="font-bold text-white mb-2 text-xs uppercase tracking-wider text-slate-400">
                            Ulasan & Bintang Pelanggan (FR-021)
                          </h4>
                          <div className="p-3 bg-slate-950 rounded-lg border border-slate-800 flex items-center justify-between">
                            <div>
                              <div className="flex items-center gap-1 text-amber-400 font-bold">
                                <Star className="w-4 h-4 fill-amber-400" /> {auditDetails.review.rating} / 5
                              </div>
                              <div className="text-slate-300 mt-1 italic">&quot;{auditDetails.review.comment || 'Tanpa komentar'}&quot;</div>
                            </div>
                            <span className="text-[10px] text-slate-500">
                              {new Date(auditDetails.review.created_at).toLocaleDateString('id-ID')}
                            </span>
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </>
            ) : null}

            {/* Modal Footer */}
            <div className="p-3 sm:p-4 bg-slate-950 border-t border-slate-800 text-right">
              <button
                onClick={() => setSelectedJobId(null)}
                className="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 text-white rounded-lg text-xs font-semibold transition-colors"
              >
                Tutup
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
