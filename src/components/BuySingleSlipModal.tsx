import React, { useState, useEffect, useRef } from 'react';
import { useApp } from '../context/AppContext';
import { ApiClient } from '../services/api';
import {
  X,
  Phone,
  Smartphone,
  ShoppingCart,
  Loader2,
  Check,
  TrendingUp,
} from 'lucide-react';

export const BuySingleSlipModal: React.FC = () => {
  const {
    selectedSlipForPayment,
    closeSingleSlipModal,
    displayPhone,
    user,
    loadSingleSlips,
    showSnack,
  } = useApp();

  const [phone, setPhone] = useState('');
  const [selectedNetwork, setSelectedNetwork] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const [isUssdOpen, setIsUssdOpen] = useState(false);
  const [isSuccessOpen, setIsSuccessOpen] = useState(false);
  const pollIntervalRef = useRef<any>(null);
  const pollCountRef = useRef(0);

  useEffect(() => {
    if (displayPhone || user?.phone_number) {
      setPhone(displayPhone || user?.phone_number || '');
    }
  }, [displayPhone, user, selectedSlipForPayment]);

  useEffect(() => {
    return () => {
      if (pollIntervalRef.current) clearInterval(pollIntervalRef.current);
    };
  }, []);

  if (!selectedSlipForPayment) return null;

  const slip = selectedSlipForPayment;
  const price = Number(slip.price) || 3000;

  const handlePay = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanPhone = phone.trim().replace(/\D/g, '');
    if (cleanPhone.length < 9) {
      showSnack('Ingiza namba sahihi ya simu', true);
      return;
    }

    setLoading(true);
    const res = await ApiClient.post('create_single_slip_order', {
      buyer_phone: cleanPhone,
      betslip_id: slip.id,
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
        loadSingleSlips();
      } else if (pollCountRef.current >= 30) {
        clearInterval(pollIntervalRef.current);
        setIsUssdOpen(false);
        showSnack('Malipo hayajakamilika. Jaribu tena.', true);
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
            onClick={closeSingleSlipModal}
            className="absolute top-4 right-4 p-1 text-[#8899AA] hover:text-white rounded-lg hover:bg-white/5"
          >
            <X className="w-4 h-4" />
          </button>

          <h3 className="text-sm font-black text-[#FFD700] tracking-wider uppercase mb-3">
            LIPIA MKEKA SINGLE
          </h3>

          <div className="p-4 rounded-xl bg-[#0A0A1A] border border-[#FFD700]/30 text-center mb-4">
            {slip.company_name && (
              <span className="text-xs font-black text-[#00FFC8] uppercase block mb-1">
                {slip.company_name}
              </span>
            )}

            <span className="text-[10px] text-[#8899AA] uppercase tracking-wider block">
              BEI YA MKEKA
            </span>
            <span className="text-3xl font-black text-[#FFD700] block mt-0.5">
              TSh {price.toLocaleString()}/=
            </span>

            {slip.odds && (
              <div className="mt-2 inline-flex items-center gap-1 text-[11px] font-black text-[#FFD700]">
                <TrendingUp className="w-3.5 h-3.5" />
                <span>ODDS: {slip.odds}</span>
              </div>
            )}
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
                  className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-[#0A0A1A] border border-white/10 focus:border-[#FFD700] focus:outline-none text-white text-sm tracking-wider font-mono"
                />
              </div>
            </div>

            {/* Network Selector */}
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
                          ? 'bg-[#FFD700]/15 border-[#FFD700] text-[#FFD700]'
                          : 'bg-[#0A0A1A] border-white/10 text-[#8899AA] hover:text-white'
                      }`}
                    >
                      <span>{net.name}</span>
                      {selected && (
                        <Check className="w-3 h-3 text-[#FFD700] mt-0.5" />
                      )}
                    </button>
                  );
                })}
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="mt-4 w-full py-3 px-4 rounded-xl bg-[#FFD700] hover:bg-[#FFE033] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg active:scale-95 disabled:opacity-50 transition-all"
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin text-black" />
              ) : (
                <>
                  <ShoppingCart className="w-4 h-4" />
                  <span>LIPIA TSh {price.toLocaleString()}/=</span>
                </>
              )}
            </button>
          </form>
        </div>
      </div>

      {/* USSD simulation */}
      {isUssdOpen && (
        <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-[#111122] border-2 border-[#FFD700]/40 p-6 shadow-2xl text-center animate-bounce-short">
            <div className="w-16 h-16 rounded-full bg-[#FFD700]/20 border border-[#FFD700]/40 flex items-center justify-center text-[#FFD700] mx-auto mb-3 animate-pulse">
              <Smartphone className="w-8 h-8" />
            </div>

            <h3 className="text-base font-black text-[#FFD700] tracking-wider uppercase">
              ANGALIA SIMU YAKO
            </h3>

            <p className="mt-2 text-xs text-white/80 leading-relaxed">
              Ujumbe wa malipo umetumwa kwenye simu yako. Ingiza namba yako ya siri kuthibitisha.
            </p>

            <div className="mt-3 p-2 rounded-lg bg-black/40 border border-white/5 font-mono text-sm text-[#FFD700] font-bold">
              {phone}
            </div>

            <div className="mt-4 flex items-center justify-center gap-2 text-xs text-[#8899AA]">
              <Loader2 className="w-4 h-4 animate-spin text-[#FFD700]" />
              <span>Tunathibitisha malipo ya mkeka...</span>
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

      {/* Victory single slip modal */}
      {isSuccessOpen && (
        <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-3xl bg-[#111122] border-2 border-[#FFD700] p-6 shadow-[0_0_50px_rgba(255,215,0,0.3)] text-center animate-scale-up">
            <div className="text-4xl mb-2">🎯</div>
            <h3 className="text-lg font-black text-[#FFD700] tracking-wider uppercase">
              HONGERA!
            </h3>
            <p className="mt-2 text-xs text-white/80 leading-relaxed">
              Umefanikiwa kununua mkeka single! Booking code yako ipo tayari kwenye "Mikeka Yangu ya Single".
            </p>

            <button
              onClick={() => {
                setIsSuccessOpen(false);
                closeSingleSlipModal();
              }}
              className="mt-5 w-full py-3 rounded-xl bg-[#FFD700] text-black font-black text-xs uppercase tracking-wider shadow-lg active:scale-95"
            >
              SAWA, NIMEONA
            </button>
          </div>
        </div>
      )}
    </>
  );
};
