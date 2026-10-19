'use client';

import React, { useState } from 'react';
import {
  Layers,
  Settings,
  Plus,
  Edit2,
  Check,
  X,
  Sliders,
  CheckCircle2,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';

interface CategoryItem {
  id: string;
  slug: string;
  name: string;
  description: string;
  iconName: string;
  isActive: boolean;
  sortOrder: number;
}

interface ConfigItem {
  key: string;
  valueInt: number;
  description: string;
}

const initialCategories: CategoryItem[] = [
  {
    id: 'cat-1',
    slug: 'bangunan',
    name: 'Tukang Bangunan',
    description: 'Renovasi rumah, pasang keramik, plester tembok, atap bocor, pengecatan',
    iconName: 'construction',
    isActive: true,
    sortOrder: 1,
  },
  {
    id: 'cat-2',
    slug: 'listrik',
    name: 'Tukang Listrik',
    description: 'Korsleting, pasang MCB, instalasi titik lampu, saklar, dan stop kontak',
    iconName: 'electrical_services',
    isActive: true,
    sortOrder: 2,
  },
  {
    id: 'cat-3',
    slug: 'pipa-plumbing',
    name: 'Tukang Pipa & Air',
    description: 'Pipa bocor/mampet, pasang kran, pompa air, toren, dan saluran sanitasi',
    iconName: 'plumbing',
    isActive: true,
    sortOrder: 3,
  },
  {
    id: 'cat-4',
    slug: 'cleaning-service',
    name: 'Cleaning Service & AC',
    description: 'Cuci AC berkala, sedot tungau, bersih rumah pasca renovasi',
    iconName: 'cleaning_services',
    isActive: true,
    sortOrder: 4,
  },
  {
    id: 'cat-5',
    slug: 'bengkel-motor',
    name: 'Bengkel Motor Panggilan',
    description: 'Motor mogok darurat, tambal/ganti ban, ganti aki, servis ringan',
    iconName: 'two_wheeler',
    isActive: true,
    sortOrder: 5,
  },
  {
    id: 'cat-6',
    slug: 'bengkel-mobil',
    name: 'Bengkel Mobil Panggilan',
    description: 'Jumper aki, ban bocor, cek mesin darurat, ganti oli di rumah',
    iconName: 'directions_car',
    isActive: true,
    sortOrder: 6,
  },
  {
    id: 'cat-7',
    slug: 'tukang-kayu',
    name: 'Tukang Kayu & Mebel',
    description: 'Perbaikan pintu/kusen, lemari, rak, kitchen set, engsel jendela',
    iconName: 'carpenter',
    isActive: true,
    sortOrder: 7,
  },
];

const initialConfigs: ConfigItem[] = [
  {
    key: 'chat_negotiating_timeout_min',
    valueInt: 30,
    description: 'Batas waktu respons chat saat NEGOTIATING sebelum lepas ke portal tanpa strike (BR-70)',
  },
  {
    key: 'depart_after_nota_timeout_min',
    valueInt: 30,
    description: 'Batas waktu wajib klik Berangkat setelah NOTA_APPROVED sebelum lepas ke portal + 1 strike (BR-31)',
  },
  {
    key: 'user_otw_arrived_chat_timeout_min',
    valueInt: 30,
    description: 'Batas waktu respons chat User saat tukang ON_THE_WAY/ARRIVED sebelum User kena 1 strike (BR-71)',
  },
  {
    key: 'otw_user_cancel_threshold_hours',
    valueInt: 3,
    description: 'Batas jam ON_THE_WAY sebelum tombol Cancel muncul di aplikasi User (BR-56b)',
  },
  {
    key: 'arrived_auto_radius_m',
    valueInt: 50,
    description: 'Jarak otomatis status ARRIVED dalam meter (BR-60)',
  },
  {
    key: 'arrived_manual_radius_m',
    valueInt: 200,
    description: 'Jarak maksimal tombol manual Saya Sudah Tiba dalam meter (BR-61)',
  },
  {
    key: 'max_monthly_strikes',
    valueInt: 3,
    description: 'Toleransi maksimal strike per bulan; strike ke-4 memicu suspend 2 hari (BR-57, BR-71)',
  },
  {
    key: 'auto_suspend_hours',
    valueInt: 48,
    description: 'Durasi suspend otomatis dalam jam (2 hari penuh)',
  },
  {
    key: 'max_active_bids',
    valueInt: 5,
    description: 'Maksimal lamaran (bid) aktif bersamaan per tukang (BR-15)',
  },
  {
    key: 'weekly_completed_quota',
    valueInt: 5,
    description: 'Maksimal job COMPLETED per minggu per tukang (BR-21)',
  },
];

export default function CategoriesAndConfigPage() {
  const [activeTab, setActiveTab] = useState<'CATEGORIES' | 'CONFIGS'>('CATEGORIES');
  const [categories, setCategories] = useState<CategoryItem[]>(initialCategories);
  const [configs, setConfigs] = useState<ConfigItem[]>(initialConfigs);

  // Edit / Add Category Modal State
  const [isCategoryModalOpen, setIsCategoryModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<CategoryItem | null>(null);
  const [catName, setCatName] = useState('');
  const [catSlug, setCatSlug] = useState('');
  const [catDesc, setCatDesc] = useState('');
  const [catIcon, setCatIcon] = useState('build');
  const [catSort, setCatSort] = useState(1);
  const [catActive, setCatActive] = useState(true);

  // Edit Config State
  const [editingConfigKey, setEditingConfigKey] = useState<string | null>(null);
  const [editingConfigVal, setEditingConfigVal] = useState<number>(0);

  const handleOpenAddCategory = () => {
    setEditingCategory(null);
    setCatName('');
    setCatSlug('');
    setCatDesc('');
    setCatIcon('tools');
    setCatSort(categories.length + 1);
    setCatActive(true);
    setIsCategoryModalOpen(true);
  };

  const handleOpenEditCategory = (cat: CategoryItem) => {
    setEditingCategory(cat);
    setCatName(cat.name);
    setCatSlug(cat.slug);
    setCatDesc(cat.description);
    setCatIcon(cat.iconName);
    setCatSort(cat.sortOrder);
    setCatActive(cat.isActive);
    setIsCategoryModalOpen(true);
  };

  const handleSaveCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!catName || !catSlug) return;

    try {
      await supabase.rpc('rpc_admin_save_category', {
        p_admin_id: '00000000-0000-0000-0000-000000000000',
        p_id: editingCategory ? editingCategory.id : null,
        p_slug: catSlug.trim().toLowerCase(),
        p_name: catName.trim(),
        p_description: catDesc.trim(),
        p_icon_name: catIcon.trim(),
        p_is_active: catActive,
        p_sort_order: catSort,
      });
    } catch {}

    if (editingCategory) {
      setCategories((prev) =>
        prev.map((c) =>
          c.id === editingCategory.id
            ? {
                ...c,
                name: catName,
                slug: catSlug,
                description: catDesc,
                iconName: catIcon,
                sortOrder: catSort,
                isActive: catActive,
              }
            : c
        )
      );
    } else {
      const newCat: CategoryItem = {
        id: `cat-${Date.now()}`,
        name: catName,
        slug: catSlug,
        description: catDesc,
        iconName: catIcon,
        sortOrder: catSort,
        isActive: catActive,
      };
      setCategories((prev) => [...prev, newCat]);
    }

    setIsCategoryModalOpen(false);
  };

  const handleToggleCategoryActive = async (id: string, current: boolean) => {
    setCategories((prev) =>
      prev.map((c) => (c.id === id ? { ...c, isActive: !current } : c))
    );
  };

  const handleSaveConfig = async (key: string) => {
    try {
      await supabase.rpc('rpc_admin_update_app_config', {
        p_admin_id: '00000000-0000-0000-0000-000000000000',
        p_key: key,
        p_value_int: editingConfigVal,
      });
    } catch {}

    setConfigs((prev) =>
      prev.map((c) => (c.key === key ? { ...c, valueInt: editingConfigVal } : c))
    );
    setEditingConfigKey(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl font-bold text-white flex items-center gap-2">
          <Layers className="w-6 h-6 text-blue-400" />
          Kategori Pekerjaan & Konfigurasi Sistem
        </h1>
        <p className="text-slate-400 text-xs mt-1">
          Pengaturan dinamis kategori jasa dan parameter timer operasional v1.4.0 tanpa rilis ulang aplikasi (FR-035).
        </p>
      </div>

      {/* Tabs Switcher */}
      <div className="flex border-b border-slate-800 gap-4">
        <button
          onClick={() => setActiveTab('CATEGORIES')}
          className={`pb-3 text-xs font-semibold flex items-center gap-2 transition-colors border-b-2 -mb-px ${
            activeTab === 'CATEGORIES'
              ? 'text-blue-400 border-blue-500'
              : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          <Layers className="w-4 h-4" /> Kategori Jasa Dinamis ({categories.length})
        </button>
        <button
          onClick={() => setActiveTab('CONFIGS')}
          className={`pb-3 text-xs font-semibold flex items-center gap-2 transition-colors border-b-2 -mb-px ${
            activeTab === 'CONFIGS'
              ? 'text-blue-400 border-blue-500'
              : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          <Settings className="w-4 h-4" /> Parameter Sistem (`app_configs`) ({configs.length})
        </button>
      </div>

      {/* TAB 1: KATEGORI DINAMIS */}
      {activeTab === 'CATEGORIES' && (
        <div className="space-y-4">
          <div className="flex justify-between items-center">
            <span className="text-xs text-slate-400">
              Kategori yang aktif langsung tampil di form pencarian tukang dan posting job user.
            </span>
            <button
              onClick={handleOpenAddCategory}
              className="px-3.5 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-semibold inline-flex items-center gap-1.5 shadow-lg shadow-blue-600/20"
            >
              <Plus className="w-4 h-4" /> Tambah Kategori
            </button>
          </div>

          <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
                <tr>
                  <th className="py-3 px-4 w-12 text-center">Urutan</th>
                  <th className="py-3 px-4">Nama Kategori & Slug</th>
                  <th className="py-3 px-4">Deskripsi</th>
                  <th className="py-3 px-4">Ikon</th>
                  <th className="py-3 px-4 text-center">Status Aktif</th>
                  <th className="py-3 px-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 text-slate-300">
                {categories.map((cat) => (
                  <tr key={cat.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3.5 px-4 text-center font-mono font-bold text-slate-400">
                      {cat.sortOrder}
                    </td>
                    <td className="py-3.5 px-4">
                      <div className="font-semibold text-white">{cat.name}</div>
                      <div className="text-[11px] text-blue-400 font-mono">slug: {cat.slug}</div>
                    </td>
                    <td className="py-3.5 px-4 max-w-sm text-slate-400 text-[11px]">
                      {cat.description}
                    </td>
                    <td className="py-3.5 px-4 font-mono text-[11px] text-slate-400">
                      {cat.iconName}
                    </td>
                    <td className="py-3.5 px-4 text-center">
                      <button
                        onClick={() => handleToggleCategoryActive(cat.id, cat.isActive)}
                        className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                          cat.isActive
                            ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                            : 'bg-slate-800 text-slate-500 border-slate-700'
                        }`}
                      >
                        {cat.isActive ? 'Aktif' : 'Nonaktif'}
                      </button>
                    </td>
                    <td className="py-3.5 px-4 text-right">
                      <button
                        onClick={() => handleOpenEditCategory(cat)}
                        className="p-1.5 hover:bg-slate-800 text-slate-400 hover:text-white rounded-lg transition-colors"
                        title="Edit Kategori"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: PARAMETER SISTEM (`app_configs`) */}
      {activeTab === 'CONFIGS' && (
        <div className="space-y-4">
          <div className="p-4 bg-blue-500/10 border border-blue-500/20 rounded-xl text-xs text-blue-300 flex items-center gap-2">
            <Sliders className="w-4 h-4 shrink-0 text-blue-400" />
            Setiap perubahan parameter operasional langsung berlaku pada mesin status, pg_cron timer, dan dicatat di audit log.
          </div>

          <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950/80 border-b border-slate-800 text-slate-400 font-semibold uppercase tracking-wider">
                <tr>
                  <th className="py-3 px-4 w-1/3">Kunci Konfigurasi</th>
                  <th className="py-3 px-4">Nilai Parameter</th>
                  <th className="py-3 px-4">Keterangan / Aturan PRD</th>
                  <th className="py-3 px-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 text-slate-300">
                {configs.map((cfg) => {
                  const isEditing = editingConfigKey === cfg.key;
                  return (
                    <tr key={cfg.key} className="hover:bg-slate-800/40 transition-colors">
                      <td className="py-3.5 px-4 font-mono font-semibold text-white">
                        {cfg.key}
                      </td>
                      <td className="py-3.5 px-4">
                        {isEditing ? (
                          <input
                            type="number"
                            value={editingConfigVal}
                            onChange={(e) => setEditingConfigVal(parseInt(e.target.value) || 0)}
                            className="w-24 bg-slate-950 border border-blue-500 rounded px-2 py-1 text-white font-mono text-xs focus:outline-none"
                            autoFocus
                          />
                        ) : (
                          <span className="font-mono font-bold text-emerald-400 bg-slate-950 px-2 py-1 rounded border border-slate-800">
                            {cfg.valueInt}
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-slate-400 text-[11px]">
                        {cfg.description}
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        {isEditing ? (
                          <div className="flex items-center justify-end gap-1">
                            <button
                              onClick={() => handleSaveConfig(cfg.key)}
                              className="p-1.5 bg-emerald-600 hover:bg-emerald-500 text-white rounded transition-colors"
                              title="Simpan"
                            >
                              <Check className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => setEditingConfigKey(null)}
                              className="p-1.5 bg-slate-800 hover:bg-slate-700 text-slate-400 rounded transition-colors"
                              title="Batal"
                            >
                              <X className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        ) : (
                          <button
                            onClick={() => {
                              setEditingConfigKey(cfg.key);
                              setEditingConfigVal(cfg.valueInt);
                            }}
                            className="px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded text-[11px] font-semibold transition-colors"
                          >
                            Ubah
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Modal Tambah / Edit Kategori */}
      {isCategoryModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl max-w-md w-full p-6 space-y-4">
            <h3 className="text-sm font-bold text-white flex items-center gap-2">
              <Layers className="w-4 h-4 text-blue-400" />
              {editingCategory ? 'Edit Kategori Jasa' : 'Tambah Kategori Jasa Baru'}
            </h3>

            <form onSubmit={handleSaveCategory} className="space-y-3">
              <div>
                <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Nama Kategori
                </label>
                <input
                  type="text"
                  value={catName}
                  onChange={(e) => {
                    setCatName(e.target.value);
                    if (!editingCategory) {
                      setCatSlug(
                        e.target.value
                          .toLowerCase()
                          .replace(/[^a-z0-9]+/g, '-')
                          .replace(/^-|-$/g, '')
                      );
                    }
                  }}
                  placeholder="Contoh: Tukang Kaca & Aluminium"
                  required
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg p-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Slug URL
                </label>
                <input
                  type="text"
                  value={catSlug}
                  onChange={(e) => setCatSlug(e.target.value)}
                  placeholder="kaca-aluminium"
                  required
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg p-2.5 text-xs text-blue-400 font-mono placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Deskripsi Keahlian
                </label>
                <textarea
                  value={catDesc}
                  onChange={(e) => setCatDesc(e.target.value)}
                  placeholder="Pasang jendela aluminium, partisi kaca kantor, aquarium..."
                  rows={2}
                  className="w-full bg-slate-950 border border-slate-800 rounded-lg p-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">
                    Nama Ikon (Material)
                  </label>
                  <input
                    type="text"
                    value={catIcon}
                    onChange={(e) => setCatIcon(e.target.value)}
                    placeholder="window"
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg p-2.5 text-xs text-white font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1">
                    Urutan Tampil
                  </label>
                  <input
                    type="number"
                    value={catSort}
                    onChange={(e) => setCatSort(parseInt(e.target.value) || 1)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-lg p-2.5 text-xs text-white font-mono focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="catActive"
                  checked={catActive}
                  onChange={(e) => setCatActive(e.target.checked)}
                  className="rounded bg-slate-950 border-slate-800 text-blue-600 focus:ring-0"
                />
                <label htmlFor="catActive" className="text-xs text-slate-300">
                  Kategori Langsung Aktif (Dapat dipilih mitra & user)
                </label>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setIsCategoryModalOpen(false)}
                  className="px-3 py-2 bg-slate-800 hover:bg-slate-700 text-slate-300 rounded-lg text-xs font-semibold"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white rounded-lg text-xs font-semibold flex items-center gap-1.5"
                >
                  <CheckCircle2 className="w-3.5 h-3.5" /> Simpan Kategori
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
