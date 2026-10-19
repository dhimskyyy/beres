'use client';

import React, { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import {
  Briefcase,
  Search,
  RefreshCw,
  Clock,
  MapPin,
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
      WORKING: { bg: 'bg-emerald-500/10 border-emerald-500/30', text: 'text-emerald-400' },
      COMPLETED: { bg: 'bg-green-500/10 border-green-500/30', text: 'text-green-400' },
      CANCELLED: { bg: 'bg-red-500/10 border-red-500/30', text: 'text-red-400' },
      EXPIRED: { bg: 'bg-slate-500/10 border-slate-500/30', text: 'text-slate-400' },
      CANCEL_PENDING: { bg: 'bg-rose-500/10 border-rose-500/30', text: 'text-rose-400' },
    };
    const style = map[status] || { bg: 'bg-slate-800 border-slate-700', text: 'text-slate-300' };
    return (
      <span className={`px-2.5 py-1 text-[11px] font-bold rounded-md border ${style.bg} ${style.text}`}>
        {status}
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className="bg-gradient-to-r from-blue-900/40 via-slate-900 to-slate-900 border border-blue-500/20 rounded-2xl p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-xl font-bold text-white flex items-center gap-2">
              <Briefcase className="w-5 h-5 text-blue-400" />
              Pengawasan 10 Status Pekerjaan (Job Marketplace)
            </h1>
            <p className="text-slate-400 text-xs mt-1">
              Pantau seluruh siklus pekerjaan mulai dari OPEN di bursa, negosiasi nota, hingga penyelesaian lapangan.
            </p>
          </div>
          <button
            onClick={fetchJobs}
            className="flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold rounded-xl border border-slate-700 transition"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Segarkan Data
          </button>
        </div>
      </div>

      {/* Filter Status Pills */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-2 scrollbar-none">
        {JOB_STATUSES.map((status) => (
          <button
            key={status}
            onClick={() => setSelectedStatus(status)}
            className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition shrink-0 ${
              selectedStatus === status
                ? 'bg-blue-600 text-white'
                : 'bg-slate-900 text-slate-400 border border-slate-800 hover:bg-slate-800 hover:text-slate-200'
            }`}
          >
            {status}
          </button>
        ))}
      </div>

      {/* Search Input */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl p-3 flex items-center gap-2">
        <Search className="w-4 h-4 text-slate-500 ml-2" />
        <input
          type="text"
          placeholder="Cari berdasarkan deskripsi kerusakan, area label kelurahan/kecamatan, atau kategori..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="bg-transparent text-xs text-white placeholder-slate-500 focus:outline-none w-full"
        />
      </div>

      {/* Table of Jobs */}
      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs text-slate-300">
            <thead className="bg-slate-800/80 text-slate-400 uppercase tracking-wider font-semibold border-b border-slate-700">
              <tr>
                <th className="py-3 px-4">Kategori & Waktu</th>
                <th className="py-3 px-4">Deskripsi Kerusakan</th>
                <th className="py-3 px-4">Area & Alamat</th>
                <th className="py-3 px-4">Pelanggan</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4">Mitra Terkunci</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800">
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-500">
                    <RefreshCw className="w-6 h-6 animate-spin mx-auto mb-2 text-blue-400" />
                    Memuat data pekerjaan...
                  </td>
                </tr>
              ) : filteredJobs.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-12 text-center text-slate-500">
                    Tidak ada pekerjaan dengan kriteria pencarian ini.
                  </td>
                </tr>
              ) : (
                filteredJobs.map((job) => (
                  <tr key={job.id} className="hover:bg-slate-800/50 transition">
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
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
