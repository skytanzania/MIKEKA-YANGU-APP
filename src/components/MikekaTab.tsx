import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { BetslipCard } from './BetslipCard';
import { PACKAGES } from '../types/mikeka';
import { Lock, RefreshCw, Zap, CheckCircle, ChevronRight, Clock, Info } from 'lucide-react';

export const MikekaTab: React.FC = () => {
  const {
    loggedIn,
    isSubscribed,
    todaysSlips,
    refreshUserData,
    openLoginModal,
    openPackagesModal,
  } = useApp();
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    setRefreshing(true);
    await refreshUserData();
    setRefreshing(false);
  };

  const handlePackageClick = (type: string) => {
    if (!loggedIn) {
      openLoginModal();
      return;
    }
    openPackagesModal(type);
  };

  return (
    <div className="min-h-full pb-20 bg-[#000010] text-[#E8EAF0]">
      {/* App Bar */}
      <div className="sticky top-0 z-20 bg-[#000010]/95 backdrop-blur border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="w-8" />
        <h1 className="text-sm font-black text-[#00FFC8] tracking-[0.2em] uppercase">
          MIKEKA YA LEO
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
        {/* Guest View */}
        {!loggedIn && (
          <>
            <div
              onClick={openLoginModal}
              className="p-4 rounded-xl bg-gradient-to-r from-[#FFD700]/15 to-[#FFD700]/5 border border-[#FFD700]/30 flex items-center gap-3 cursor-pointer hover:border-[#FFD700]/50 transition-all active:scale-[0.99]"
            >
              <div className="p-2 rounded-lg bg-[#FFD700]/20 text-[#FFD700]">
                <Info className="w-6 h-6" />
              </div>
              <div className="flex-1 min-w-0">
                <h3 className="text-sm font-black text-[#FFD700]">
                  Karibu Mikeka App!
                </h3>
                <p className="text-[11px] text-white/70">
                  Ingia au jisajili ili kuweza kununua mikeka na kufuata tipsters
                </p>
              </div>
              <ChevronRight className="w-5 h-5 text-[#FFD700]" />
            </div>

            <PackagesList onSelect={handlePackageClick} />
          </>
        )}

        {/* Logged in but not subscribed */}
        {loggedIn && !isSubscribed && (
          <>
            <div className="p-6 rounded-2xl bg-gradient-to-br from-[#111122] to-[#1A1A2E] border border-white/10 shadow-xl flex flex-col items-center text-center">
              <div className="w-16 h-16 rounded-full bg-[#00FFC8]/10 border border-[#00FFC8]/30 flex items-center justify-center text-[#00FFC8] mb-3">
                <Lock className="w-8 h-8" />
              </div>
              <h2 className="text-lg font-black text-[#00FFC8] tracking-wider uppercase">
                FUNGUA MKEKA
              </h2>
              <p className="mt-1 text-xs text-[#8899AA] leading-relaxed max-w-xs">
                Lipia kifurushi chochote ili kuona mkeka wa leo wenye odds za uhakika!
              </p>

              <button
                onClick={() => openPackagesModal()}
                className="mt-4 w-full py-3 px-4 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg hover:bg-[#00e6b4] active:scale-[0.98] transition-all"
              >
                <Zap className="w-4 h-4 fill-black" />
                <span>LIPIA SASA</span>
              </button>
            </div>

            <PackagesList onSelect={handlePackageClick} />
          </>
        )}

        {/* Logged in, Subscribed, but no slips loaded today */}
        {loggedIn && isSubscribed && todaysSlips.length === 0 && (
          <div className="p-6 rounded-2xl bg-gradient-to-br from-[#111122] to-[#1A1A2E] border border-white/10 shadow-xl flex flex-col items-center text-center">
            <div className="w-16 h-16 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-[#8899AA] mb-3">
              <Clock className="w-8 h-8" />
            </div>
            <h2 className="text-base font-black text-[#E8EAF0] tracking-wider uppercase">
              MKEKA HAUJAPAKIWA
            </h2>
            <p className="mt-2 text-xs text-[#8899AA] leading-relaxed">
              Hongera! Tumepokea malipo yako. Wataalam wanasuka mikeka kwa ajili yako.
              Mkeka wa leo bado haujapakiwa. Tafadhali subiri ndani ya dakika chache kisha rudi tena.
            </p>
          </div>
        )}

        {/* Logged in, Subscribed, Slips Available */}
        {loggedIn && isSubscribed && todaysSlips.length > 0 && (
          <div className="space-y-3">
            <div className="flex items-center justify-between px-1">
              <span className="text-xs font-black text-[#FFD700] uppercase tracking-wider">
                MIKEKA YA LEO ({todaysSlips.length})
              </span>
              <span className="text-[10px] text-[#00C853] font-bold uppercase tracking-wider bg-[#00C853]/15 px-2 py-0.5 rounded-full border border-[#00C853]/30">
                VIP ACTIVE
              </span>
            </div>

            {todaysSlips.map((s) => (
              <BetslipCard key={s.id} slip={s} isBlurred={false} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

const PackagesList: React.FC<{ onSelect: (type: string) => void }> = ({ onSelect }) => {
  return (
    <div className="space-y-3 pt-2">
      <h3 className="text-xs font-black text-[#FFD700] tracking-wider uppercase px-1">
        CHAGUA KIFURUSHI
      </h3>

      {Object.values(PACKAGES).map((pkg) => (
        <div
          key={pkg.type}
          className="p-4 rounded-xl border bg-[#0A0A1A] transition-all hover:scale-[1.01]"
          style={{
            borderColor: `${pkg.color}55`,
            backgroundImage: `linear-gradient(to right, #0A0A1A 60%, ${pkg.color}15 100%)`,
          }}
        >
          <div className="flex items-center justify-between">
            <span
              className="text-lg font-black tracking-wider"
              style={{ color: pkg.color }}
            >
              {pkg.name}
            </span>
            <span
              className="text-[11px] font-bold uppercase"
              style={{ color: pkg.color }}
            >
              {pkg.duration}
            </span>
          </div>

          <div
            className="mt-1 text-2xl font-black"
            style={{ color: pkg.color }}
          >
            TSh {pkg.price.toLocaleString()}/=
          </div>

          <button
            onClick={() => onSelect(pkg.type)}
            className="mt-3 w-full py-2.5 px-4 rounded-xl font-black text-xs text-black uppercase tracking-wider flex items-center justify-center gap-1.5 shadow-lg active:scale-[0.98] transition-all"
            style={{ backgroundColor: pkg.color }}
          >
            <CheckCircle className="w-4 h-4 fill-black text-white" />
            <span>LIPIA TSh {pkg.price.toLocaleString()}/= — {pkg.name}</span>
          </button>
        </div>
      ))}
    </div>
  );
};
