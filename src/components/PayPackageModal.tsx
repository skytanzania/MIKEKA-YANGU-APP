import React, { useState, useEffect, useRef } from 'react';
import { useApp } from '../context/AppContext';
import { PACKAGES } from '../types/mikeka';
import { ApiClient } from '../services/api';
import {
  X,
  Phone,
  Smartphone,
  CheckCircle,
  Trophy,
  Loader2,
  AlertCircle,
  Check,
} from 'lucide-react';

export const PayPackageModal: React.FC = () => {
  const {
    isPackagesModalOpen,
    closePackagesModal,
    selectedPackageForPayment,
    displayPhone,
    user,
    refreshUserData,
    showSnack,
  } = useApp();

  const [activePackageType, setActivePackageType] = useState<string>('normal');
  const [phone, setPhone] = useState('');
  const [selectedNetwork, setSelectedNetwork] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  // USSD / Polling state
  const [isUssdOpen, setIsUssdOpen] = useState(false);
  const [isSuccessOpen, setIsSuccessOpen] = useState(false);
  const pollIntervalRef = useRef<any>(null);
  const pollCountRef = useRef(0);

  useEffect(() => {
    if (selectedPackageForPayment) {
      setActivePackageType(selectedPackageForPayment);
    }
    if (displayPhone || user?.phone_number) {
      setPhone(displayPhone || user?.phone_number || '');
    }
  }, [selectedPackageForPayment, displayPhone, user, isPackagesModalOpen]);

  useEffect(() => {
    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, []);

  if (!isPackagesModalOpen) return null;

  const pkg = PACKAGES[activePackageType] || PACKAGES.normal;

  const handlePay = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanPhone = phone.trim().replace(/\D/g, '');
    if (cleanPhone.length < 9) {
      showSnack('Ingiza namba sahihi ya simu', true);
      return;
    }

    setLoading(true);
    const res = await ApiClient.post('create_order', {
      buyer_phone: cleanPhone,
      package_type: activePackageType,
    });
    setLoading(false);

    if (res.success && res.order_id) {
      setIsUssdOpen(true);
      startPolling(String(res.order_id));
    } else {
      showSnack(res.error || 'Malipo yameshindikana. Jaribu tena.', true);
    }
  };

  const startPolling = (orderId: string) => {
    if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    pollCountRef.current = 0;

    pollIntervalRef.current = setInterval(async () => {
      pollCountRef.current += 1;
      const res = await ApiClient.post('check_status', { order_id: orderId });

      if (res.success && res.is_payment_successful) {
        clearInterval(pollIntervalRef.current);
        setIsUssdOpen(false);
        setIsSuccessOpen(true);
        refreshUserData();
      } else if (pollCountRef.current >= 30) {
        clearInterval(pollIntervalRef.current);
        setIsUssdOpen(false);
        showSnack('Muda wa malipo umekwisha. Jaribu tena.', true);
      }
    }, 2000);
  };

  const cancelUssd = () => {
    if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    setIsUssdOpen(false);
  };

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/15 p-5 shadow-2xl relative my-auto animate-scale-up">
          <button
            onClick={closePackagesModal}
            className="absolute top-4 right-4 p-1 text-[#8899AA] hover:text-white rounded-lg hover:bg-white/5"
          >
            <X className="w-4 h-4" />
          </button>

          <h3 className="text-sm font-black text-[#00FFC8] tracking-wider uppercase mb-3">
            LIPIA KIFURUSHI
          </h3>

          {/* Package Selector Pills */}
          <div className="grid grid-cols-4 gap-1.5 mb-4">
            {Object.values(PACKAGES).map((p) => {
              const active = p.type === activePackageType;
              return (
                <button
                  key={p.type}
                  type="button"
                  onClick={() => setActivePackageType(p.type)}
                  className={`py-1.5 px-1 rounded-lg text-[10px] font-black uppercase tracking-wider transition-all text-center border ${
                    active
                      ? 'border-white text-black shadow-lg scale-105'
                      : 'border-white/10 text-white/60 hover:text-white'
                  }`}
                  style={{
                    backgroundColor: active ? p.color : '#0A0A1A',
                  }}
                >
                  {p.name}
                </button>
              );
            })}
          </div>

          {/* Package Highlight Box */}
          <div
            className="p-4 rounded-xl border mb-4 text-center"
            style={{
              borderColor: `${pkg.color}60`,
              backgroundImage: `linear-gradient(to bottom, #0A0A1A, ${pkg.color}15)`,
            }}
          >
            <span
              className="text-xs font-bold uppercase tracking-widest block"
              style={{ color: pkg.color }}
            >
              {pkg.duration}
            </span>
            <span
              className="text-3xl font-black block mt-1"
              style={{ color: pkg.color }}
            >
              TSh {pkg.price.toLocaleString()}/=
            </span>
          </div>

          <form onSubmit={handlePay} className="space-y-3">
            <div>
              <label className="block text-[11px] font-bold text-[#8899AA] uppercase tracking-wider mb-1">
                Namba ya Simu ya Kulipa
              </label>
              <div className="relative">
                <Phone className="w-4 h-4 text-[#00FFC8] absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="0762xxxxxx au 255762xxxxxx"
                  required
                  className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#0A0A1A] border border-white/10 focus:border-[#00FFC8] focus:outline-none text-white text-sm tracking-wider font-mono"
                />
              </div>
            </div>

            {/* Mobile Network Selector */}
            <div>
              <label className="block text-[11px] font-bold text-[#8899AA] uppercase tracking-wider mb-1">
                Chagua Mtandao (Si lazima)
              </label>
              <div className="grid grid-cols-4 gap-1.5">
                {[
                  { name: 'VODACOM', code: 'vodacom' },
                  { name: 'YAS', code: 'yas' },
                  { name: 'AIRTEL', code: 'airtel' },
                  { name: 'HALOTEL', code: 'halotel' },
                ].map((net) => {
                  const selected = selectedNetwork === net.code;
                  return (
                    <button
                      key={net.code}
                      type="button"
                      onClick={() =>
                        setSelectedNetwork(selected ? null : net.code)
                      }
                      className={`py-2 px-1 rounded-lg text-[9px] font-black uppercase tracking-wider border transition-all flex flex-col items-center justify-center ${
                        selected
                          ? 'bg-[#00FFC8]/15 border-[#00FFC8] text-[#00FFC8]'
                          : 'bg-[#0A0A1A] border-white/10 text-[#8899AA] hover:text-white'
                      }`}
                    >
                      <span>{net.name}</span>
                      {selected && (
                        <Check className="w-3 h-3 text-[#00FFC8] mt-0.5" />
                      )}
                    </button>
                  );
                })}
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="mt-4 w-full py-3 px-4 rounded-xl text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg active:scale-95 disabled:opacity-50 transition-all"
              style={{ backgroundColor: pkg.color }}
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin text-black" />
              ) : (
                <>
                  <CheckCircle className="w-4 h-4 fill-black text-white" />
                  <span>LIPIA TSh {pkg.price.toLocaleString()}/=</span>
                </>
              )}
            </button>
          </form>
        </div>
      </div>

      {/* USSD Push Notification Simulation Dialog */}
      {isUssdOpen && (
        <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-[#111122] border-2 border-[#00FFC8]/40 p-6 shadow-2xl text-center animate-bounce-short">
            <div className="w-16 h-16 rounded-full bg-[#00FFC8]/20 border border-[#00FFC8]/40 flex items-center justify-center text-[#00FFC8] mx-auto mb-3 animate-pulse">
              <Smartphone className="w-8 h-8" />
            </div>

            <h3 className="text-base font-black text-[#00FFC8] tracking-wider uppercase">
              ANGALIA SIMU YAKO
            </h3>

            <p className="mt-2 text-xs text-white/80 leading-relaxed">
              Ujumbe wa malipo umetumwa kwenye simu yako. Tafadhali ingiza namba yako ya siri kuthibitisha.
            </p>

            <div className="mt-3 p-2 rounded-lg bg-black/40 border border-white/5 font-mono text-sm text-[#00FFC8] font-bold">
              {phone}
            </div>

            <div className="mt-4 flex items-center justify-center gap-2 text-xs text-[#8899AA]">
              <Loader2 className="w-4 h-4 animate-spin text-[#00FFC8]" />
              <span>Tunathibitisha malipo yako...</span>
            </div>

            <button
              onClick={cancelUssd}
              className="mt-5 w-full py-2.5 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
            >
              FUNGA
            </button>
          </div>
        </div>
      )}

      {/* Victory Celebration Modal */}
      {isSuccessOpen && (
        <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-3xl bg-gradient-to-b from-[#0A1A00] to-[#1A3A00] border-2 border-[#00C853] p-6 shadow-[0_0_50px_rgba(0,200,83,0.35)] text-center animate-scale-up">
            <div className="w-16 h-16 rounded-full bg-[#00C853]/20 border border-[#00C853] flex items-center justify-center text-[#00C853] mx-auto mb-3">
              <Trophy className="w-8 h-8 animate-bounce" />
            </div>

            <h3 className="text-xl font-black text-[#00C853] tracking-wider uppercase">
              HONGERA SANA!
            </h3>

            <p className="mt-1 text-xs text-white/80">
              Malipo yako yamekamilika kwa ufanisi.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-black/40 border border-[#00C853]/30">
              <span className="text-sm font-black text-[#FFD700] uppercase block">
                {pkg.name}
              </span>
              <span className="text-[11px] text-[#00FFC8] block mt-0.5">
                {pkg.duration}
              </span>
              <span className="text-2xl font-black text-[#FFD700] block mt-1">
                TSh {pkg.price.toLocaleString()}/=
              </span>
            </div>

            <button
              onClick={() => {
                setIsSuccessOpen(false);
                closePackagesModal();
              }}
              className="mt-5 w-full py-3 rounded-xl bg-[#00C853] text-black font-black text-xs uppercase tracking-wider shadow-lg active:scale-95"
            >
              SAWA, NIMEKUELEWA
            </button>
          </div>
        </div>
      )}
    </>
  );
};
