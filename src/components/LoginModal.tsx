import React, { useState } from 'react';
import { ApiClient } from '../services/api';
import { useApp } from '../context/AppContext';
import { Phone, UserPlus, ArrowRight, Loader2, X, Check } from 'lucide-react';

export const LoginModal: React.FC = () => {
  const { isLoginModalOpen, closeLoginModal, applyUserData, showSnack } = useApp();
  const [phone, setPhone] = useState('');
  const [confirmPhone, setConfirmPhone] = useState('');
  const [step, setStep] = useState<'input' | 'confirm'>('input');
  const [loading, setLoading] = useState(false);

  if (!isLoginModalOpen) return null;

  const handleInitialSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanPhone = phone.trim().replace(/\D/g, '');
    if (cleanPhone.length < 9) {
      showSnack('Ingiza namba sahihi ya simu (mfano 0762xxxxxx)', true);
      return;
    }

    setLoading(true);
    const res = await ApiClient.post('login', { phone: cleanPhone }, false);
    setLoading(false);

    if (res.success) {
      if (res.action === 'need_confirmation') {
        setStep('confirm');
      } else if (res.session_token) {
        ApiClient.setToken(res.session_token);
        const userDataRes = await ApiClient.post('get_user_data');
        if (userDataRes.success) {
          applyUserData(userDataRes);
        }
        showSnack('Umefanikiwa kuingia!');
        closeLoginModal();
      }
    } else if (res.banned) {
      showSnack(res.ban_reason || 'Akaunti yako imefungwa.', true);
    } else {
      showSnack(res.error || 'Imeshindikana kuingia. Jaribu tena.', true);
    }
  };

  const handleConfirmSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const p1 = phone.trim().replace(/\D/g, '');
    const p2 = confirmPhone.trim().replace(/\D/g, '');

    const formatP = (raw: string) => {
      if (raw.startsWith('0') && raw.length === 10) return '255' + raw.substring(1);
      if (raw.length === 9) return '255' + raw;
      return raw;
    };

    if (formatP(p1) !== formatP(p2)) {
      showSnack('Namba hazilingani. Tafadhali hakiki tena.', true);
      return;
    }

    setLoading(true);
    const cres = await ApiClient.post('confirm_phone', { phone: p1 }, false);
    if (cres.success && cres.session_token) {
      ApiClient.setToken(cres.session_token);
      const userDataRes = await ApiClient.post('get_user_data');
      if (userDataRes.success) {
        applyUserData(userDataRes);
      }
      showSnack('Akaunti imehakikiwa na kuingia!');
      closeLoginModal();
    } else {
      showSnack(cres.error || 'Uhakiki umeshindikana.', true);
    }
    setLoading(false);
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/15 p-5 shadow-2xl relative animate-scale-up">
        <button
          onClick={closeLoginModal}
          className="absolute top-4 right-4 p-1 text-[#8899AA] hover:text-white rounded-lg hover:bg-white/5"
        >
          <X className="w-4 h-4" />
        </button>

        {step === 'input' ? (
          <div>
            <div className="flex items-center gap-2.5 mb-3">
              <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-[#00FFC8] to-[#00B4FF] flex items-center justify-center text-black">
                <UserPlus className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-sm font-black text-[#00FFC8] tracking-wider uppercase">
                  INGIA / JISAJILI
                </h3>
                <span className="text-[10px] text-[#8899AA]">Mikeka App Tanzania</span>
              </div>
            </div>

            <p className="text-xs text-white/70 leading-relaxed mb-4">
              Ingiza namba yako ya simu ili kuendelea na kununua mikeka, kufuata tipsters, na kupata huduma zote.
            </p>

            <form onSubmit={handleInitialSubmit} className="space-y-3">
              <div>
                <label className="block text-[11px] font-bold text-[#8899AA] uppercase tracking-wider mb-1">
                  Namba ya Simu
                </label>
                <div className="relative">
                  <Phone className="w-4 h-4 text-[#00FFC8] absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="0762xxxxxx au 255762xxxxxx"
                    autoFocus
                    required
                    className="w-full pl-9 pr-3 py-3 rounded-xl bg-[#0A0A1A] border border-white/10 focus:border-[#00FFC8] focus:outline-none text-white text-sm tracking-wider font-mono"
                  />
                </div>
                <span className="text-[10px] text-[#8899AA] block mt-1">
                  Unaweza kuingiza kuanzia 0 (076...) au 255 (255762...)
                </span>
              </div>

              <div className="pt-2 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={closeLoginModal}
                  className="px-4 py-2.5 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
                >
                  GHAIRI
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="px-5 py-2.5 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider flex items-center gap-1.5 shadow-lg hover:bg-[#00e6b4] active:scale-95 disabled:opacity-50"
                >
                  {loading ? (
                    <Loader2 className="w-4 h-4 animate-spin text-black" />
                  ) : (
                    <>
                      <span>ENDELEA</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        ) : (
          <div>
            <div className="text-center mb-4">
              <h3 className="text-sm font-black text-[#00FFC8] tracking-wider uppercase">
                RUDIA TENA NAMBA YAKO
              </h3>
              <div className="mt-2 text-xl font-black text-[#00FFC8] tracking-widest font-mono">
                {phone}
              </div>
              <p className="mt-1 text-xs text-[#8899AA]">
                Ingiza namba tena kuhakiki kuwa ni sahihi kabisa
              </p>
            </div>

            <form onSubmit={handleConfirmSubmit} className="space-y-3">
              <input
                type="tel"
                value={confirmPhone}
                onChange={(e) => setConfirmPhone(e.target.value)}
                placeholder="Weka namba tena"
                autoFocus
                required
                className="w-full px-3 py-3 rounded-xl bg-[#0A0A1A] border border-white/10 focus:border-[#00FFC8] focus:outline-none text-white text-sm tracking-wider font-mono text-center"
              />

              <div className="pt-2 flex items-center justify-between gap-2">
                <button
                  type="button"
                  onClick={() => setStep('input')}
                  className="px-3 py-2 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
                >
                  Rudi Nyuma
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="px-5 py-2.5 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider flex items-center gap-1.5 shadow-lg hover:bg-[#00e6b4] active:scale-95 disabled:opacity-50"
                >
                  {loading ? (
                    <Loader2 className="w-4 h-4 animate-spin text-black" />
                  ) : (
                    <>
                      <Check className="w-3.5 h-3.5" strokeWidth={3} />
                      <span>THIBITISHA</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    </div>
  );
};
