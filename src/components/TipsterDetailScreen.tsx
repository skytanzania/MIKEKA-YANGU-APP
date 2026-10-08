import React, { useState, useEffect } from 'react';
import { Tipster } from '../types/mikeka';
import { ApiClient } from '../services/api';
import { useApp } from '../context/AppContext';
import { BetslipCard } from './BetslipCard';
import { SingleSlipCard } from './SingleSlipCard';
import {
  ArrowLeft,
  Check,
  UserPlus,
  Star,
  Award,
  Loader2,
  AlertCircle,
} from 'lucide-react';

interface Props {
  tipsterId: number;
  onBack: () => void;
}

export const TipsterDetailScreen: React.FC<Props> = ({ tipsterId, onBack }) => {
  const { isSubscribed, toggleFollowTipster, openSingleSlipModal } = useApp();
  const [tipster, setTipster] = useState<Tipster | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchTipster = async () => {
    setLoading(true);
    const res = await ApiClient.post('get_tipster_with_slips', { tipster_id: tipsterId });
    if (res.success && res.tipster) {
      setTipster(res.tipster);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchTipster();
  }, [tipsterId]);

  const handleFollowToggle = async () => {
    if (!tipster) return;
    const current = !!tipster.is_following;
    const result = await toggleFollowTipster(tipsterId, current);
    if (result.success) {
      setTipster((prev) =>
        prev
          ? {
              ...prev,
              is_following: !current,
              followers_count: Math.max(0, (prev.followers_count || 0) + (current ? -1 : 1)),
            }
          : null
      );
    }
  };

  const name = tipster?.tipster_name || tipster?.name || 'Tipster';
  const verified = !!tipster?.tipster_verified;
  const rating = Number(tipster?.tipster_rating) || 5.0;
  const winRate = Number(tipster?.tipster_success_rate) || 75;
  const isFollowing = !!tipster?.is_following;

  return (
    <div className="min-h-full pb-20 bg-[#000010] text-[#E8EAF0]">
      {/* App Bar */}
      <div className="sticky top-0 z-30 bg-[#000010]/95 backdrop-blur border-b border-white/10 px-4 py-3 flex items-center gap-3">
        <button
          onClick={onBack}
          className="p-1.5 -ml-1.5 rounded-lg text-[#00FFC8] hover:bg-white/5 active:scale-95 transition-all"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h1 className="text-sm font-black text-[#00FFC8] tracking-widest uppercase truncate flex-1">
          {name}
        </h1>
      </div>

      {loading ? (
        <div className="py-24 flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-8 h-8 text-[#00FFC8] animate-spin" />
          <span className="text-xs text-[#8899AA]">Inapakia taarifa za Tipster...</span>
        </div>
      ) : !tipster ? (
        <div className="py-24 px-6 text-center">
          <AlertCircle className="w-12 h-12 text-[#8899AA] mx-auto mb-2" />
          <p className="text-sm text-[#8899AA]">Tipster haipatikani kwa sasa.</p>
          <button
            onClick={onBack}
            className="mt-4 px-4 py-2 rounded-xl bg-white/10 text-xs font-bold text-[#00FFC8]"
          >
            Rudi Nyuma
          </button>
        </div>
      ) : (
        <div className="p-4 space-y-4">
          {/* Header Card */}
          <div className="p-4 rounded-2xl bg-gradient-to-br from-[#111122] to-[#1A1A2E] border border-white/10 shadow-xl flex flex-col items-center text-center">
            {/* Avatar with gradient border */}
            <div className="relative">
              <div className="w-20 h-20 rounded-full p-[2px] bg-gradient-to-tr from-[#00FFC8] to-[#FFD700] shadow-[0_0_20px_rgba(0,255,200,0.25)]">
                <div className="w-full h-full rounded-full bg-[#000010] overflow-hidden flex items-center justify-center">
                  {tipster.tipster_avatar && tipster.tipster_avatar.startsWith('http') ? (
                    <img
                      src={tipster.tipster_avatar}
                      alt={name}
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        (e.target as HTMLElement).style.display = 'none';
                      }}
                    />
                  ) : (
                    <span className="text-2xl font-black text-[#00FFC8]">
                      {name[0]?.toUpperCase() || 'T'}
                    </span>
                  )}
                </div>
              </div>

              {verified && (
                <div className="absolute bottom-0 right-0 p-1 bg-[#1DA1F2] rounded-full border-2 border-[#000010] shadow">
                  <Check className="w-3 h-3 text-white" strokeWidth={3} />
                </div>
              )}
            </div>

            <h2 className="mt-3 text-lg font-black text-white">{name}</h2>

            {tipster.tipster_badge && (
              <div className="mt-1 px-3 py-0.5 rounded-full bg-[#FFD700]/15 border border-[#FFD700]/30 text-[10px] font-black text-[#FFD700] flex items-center gap-1 uppercase tracking-wider">
                <Award className="w-3 h-3 text-[#FFD700]" />
                <span>{tipster.tipster_badge}</span>
              </div>
            )}

            {/* Rating Stars */}
            <div className="mt-2 flex items-center gap-1 text-[#FFD700]">
              <Star className="w-4 h-4 fill-[#FFD700]" />
              <span className="text-xs font-black">{rating.toFixed(1)}</span>
            </div>

            {/* Stats Row */}
            <div className="mt-4 w-full grid grid-cols-3 divide-x divide-white/5 py-2 rounded-xl bg-black/20 border border-white/5">
              <div>
                <div className="text-base font-black text-[#00FFC8]">
                  {tipster.followers_count || 0}
                </div>
                <div className="text-[10px] text-[#8899AA] uppercase tracking-wider font-medium">
                  Wafuasi
                </div>
              </div>
              <div>
                <div className="text-base font-black text-[#00FFC8]">
                  {tipster.tips_count || 0}
                </div>
                <div className="text-[10px] text-[#8899AA] uppercase tracking-wider font-medium">
                  Tips
                </div>
              </div>
              <div>
                <div className="text-base font-black text-[#00FFC8]">
                  {winRate.toFixed(0)}%
                </div>
                <div className="text-[10px] text-[#8899AA] uppercase tracking-wider font-medium">
                  Mafanikio
                </div>
              </div>
            </div>

            {/* Bio */}
            {tipster.tipster_bio && (
              <p className="mt-3 text-xs text-white/70 leading-relaxed bg-white/[0.02] p-2.5 rounded-lg border border-white/5 w-full text-left">
                {tipster.tipster_bio}
              </p>
            )}
          </div>

          {/* Follow Button */}
          <button
            onClick={handleFollowToggle}
            className={`w-full py-3 px-4 rounded-xl font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg transition-all active:scale-[0.98] ${
              isFollowing
                ? 'bg-[#00C853]/20 border border-[#00C853]/40 text-[#00C853]'
                : 'bg-[#00FFC8] text-black hover:bg-[#00e6b4]'
            }`}
          >
            {isFollowing ? (
              <>
                <Check className="w-4 h-4" />
                <span>Following</span>
              </>
            ) : (
              <>
                <UserPlus className="w-4 h-4" />
                <span>Follow Tipster</span>
              </>
            )}
          </button>

          {/* Mikeka Mipya Section */}
          <div className="pt-2">
            <h3 className="text-xs font-black text-[#FFD700] tracking-wider uppercase mb-3 flex items-center gap-1.5">
              <span>MIKEKA MIPYA</span>
            </h3>

            {tipster.slips && tipster.slips.length > 0 ? (
              tipster.slips.map((slip) => (
                <BetslipCard key={slip.id} slip={slip} isBlurred={!isSubscribed} />
              ))
            ) : tipster.system_betslip ? (
              <div>
                <p className="text-[11px] text-[#8899AA] mb-2 uppercase font-bold tracking-wider">
                  MKEKA WA SYSTEM
                </p>
                <BetslipCard slip={tipster.system_betslip} isBlurred={!isSubscribed} isSystemGenerated />
              </div>
            ) : (
              <div className="p-4 rounded-xl bg-[#111122] border border-white/5 text-center">
                <p className="text-xs text-[#8899AA]">
                  Tipster huyu hajatoa mikeka bado. Follow kupata notification.
                </p>
              </div>
            )}
          </div>

          {/* Mikeka ya Single Section */}
          {tipster.single_slips && tipster.single_slips.length > 0 && (
            <div className="pt-2">
              <h3 className="text-xs font-black text-[#FFD700] tracking-wider uppercase mb-3">
                MIKEKA YA SINGLE
              </h3>
              {tipster.single_slips.map((slip) => (
                <SingleSlipCard
                  key={slip.id}
                  slip={slip}
                  onBuy={() => openSingleSlipModal(slip)}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
};
