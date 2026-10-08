import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { SingleSlipCard } from './SingleSlipCard';
import { SingleSlip } from '../types/mikeka';
import { RefreshCw, Target, ShieldCheck } from 'lucide-react';

export const SingleSlipsTab: React.FC = () => {
  const {
    loggedIn,
    singleSlips,
    purchasedSingleSlips,
    loadSingleSlips,
    openSingleSlipModal,
    openLoginModal,
  } = useApp();
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadSingleSlips();
    setRefreshing(false);
  };

  const handleBuy = (slip: SingleSlip) => {
    if (!loggedIn) {
      openLoginModal();
      return;
    }
    openSingleSlipModal(slip);
  };

  return (
    <div className="min-h-full pb-20 bg-[#000010] text-[#E8EAF0]">
      {/* App Bar */}
      <div className="sticky top-0 z-20 bg-[#000010]/95 backdrop-blur border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="w-8" />
        <h1 className="text-sm font-black text-[#00FFC8] tracking-[0.2em] uppercase">
          SINGLE SLIPS
        </h1>
        <button
          onClick={handleRefresh}
          className="p-1.5 rounded-lg text-[#00FFC8] hover:bg-white/5 active:scale-95 transition-all"
          title="Refresh"
        >
          <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
        </button>
      </div>

      <div className="p-4 space-y-4">
        {singleSlips.length === 0 ? (
          <div className="p-6 rounded-2xl bg-[#111122] border border-white/10 text-center flex flex-col items-center">
            <Target className="w-12 h-12 text-[#8899AA] mb-3" />
            <h3 className="text-xs font-black text-[#8899AA] tracking-wider uppercase">
              HAKUNA MIKEKA YA SINGLE
            </h3>
            <p className="mt-2 text-xs text-[#8899AA] leading-relaxed">
              Wataalam wetu hawajatoa mikeka ya single bado. Endelea kufuatilia!
            </p>
          </div>
        ) : (
          <div>
            <h3 className="text-xs font-black text-[#FFD700] tracking-wider uppercase mb-3 px-1 flex items-center gap-1.5">
              <span>MIKEKA YA SINGLE — NUNUA MMOJA MMOJA</span>
            </h3>

            <div className="space-y-3">
              {singleSlips.map((s) => (
                <SingleSlipCard
                  key={s.id}
                  slip={s}
                  onBuy={() => handleBuy(s)}
                />
              ))}
            </div>
          </div>
        )}

        {/* Purchased single slips section */}
        {loggedIn && purchasedSingleSlips.length > 0 && (
          <div className="pt-4 border-t border-white/10">
            <h3 className="text-xs font-black text-[#00C853] tracking-wider uppercase mb-3 px-1 flex items-center gap-1.5">
              <ShieldCheck className="w-4 h-4" />
              <span>MIKEKA YANGU YA SINGLE ({purchasedSingleSlips.length})</span>
            </h3>

            <div className="space-y-3">
              {purchasedSingleSlips.map((s) => (
                <SingleSlipCard key={s.id} slip={s} purchased={true} />
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
