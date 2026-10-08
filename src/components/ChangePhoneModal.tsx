import React, { useState } from 'react';
import { ApiClient } from '../services/api';
import { useApp } from '../context/AppContext';
import { Phone, X, Loader2, Check } from 'lucide-react';

interface Props {
  onClose: () => void;
}

export const ChangePhoneModal: React.FC<Props> = ({ onClose }) => {
  const { displayPhone, user, refreshUserData, showSnack } = useApp();
  const [newPhone, setNewPhone] = useState(displayPhone || user?.phone_number || '');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const clean = newPhone.trim().replace(/\D/g, '');
    if (clean.length < 9) {
      showSnack('Ingiza namba sahihi ya simu', true);
      return;
    }

    setLoading(true);
    const res = await ApiClient.post('update_phone', { phone: clean });
    setLoading(false);

    if (res.success) {
      showSnack(res.message || 'Namba imebadilishwa!');
      await refreshUserData();
      onClose();
    } else {
      showSnack(res.error || 'Hitilafu kubadili namba', true);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/15 p-5 shadow-2xl relative animate-scale-up">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 p-1 text-[#8899AA] hover:text-white rounded-lg hover:bg-white/5"
        >
          <X className="w-4 h-4" />
        </button>

        <h3 className="text-sm font-black text-[#00FFC8] tracking-wider uppercase mb-1">
          BADILISHA NAMBA
        </h3>
        <p className="text-xs text-[#8899AA] mb-4">
          Weka namba mpya ya simu utakayotumia kupokea mikeka na kufanya malipo.
        </p>

        <form onSubmit={handleSubmit} className="space-y-3">
          <div className="relative">
            <Phone className="w-4 h-4 text-[#00FFC8] absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="tel"
              value={newPhone}
              onChange={(e) => setNewPhone(e.target.value)}
              placeholder="0762xxxxxx au 255762xxxxxx"
              autoFocus
              required
              className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#0A0A1A] border border-white/10 focus:border-[#00FFC8] focus:outline-none text-white text-sm tracking-wider font-mono"
            />
          </div>

          <div className="pt-2 flex items-center justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
            >
              GHAIRI
            </button>
            <button
              type="submit"
              disabled={loading}
              className="px-5 py-2.5 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider flex items-center gap-1.5 shadow-lg active:scale-95 disabled:opacity-50"
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin text-black" />
              ) : (
                <>
                  <Check className="w-3.5 h-3.5" strokeWidth={3} />
                  <span>BADILISHA</span>
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
