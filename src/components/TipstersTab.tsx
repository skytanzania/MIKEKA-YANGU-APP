import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { Tipster } from '../types/mikeka';
import { TipsterDetailScreen } from './TipsterDetailScreen';
import { Star, Check, UserPlus, RefreshCw, Users } from 'lucide-react';

export const TipstersTab: React.FC = () => {
  const { tipsters, loadTipsters, toggleFollowTipster } = useApp();
  const [selectedTipsterId, setSelectedTipsterId] = useState<number | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadTipsters();
    setRefreshing(false);
  };

  if (selectedTipsterId !== null) {
    return (
      <TipsterDetailScreen
        tipsterId={selectedTipsterId}
        onBack={() => setSelectedTipsterId(null)}
      />
    );
  }

  return (
    <div className="min-h-full pb-20 bg-[#000010] text-[#E8EAF0]">
      {/* App Bar */}
      <div className="sticky top-0 z-20 bg-[#000010]/95 backdrop-blur border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="w-8" />
        <h1 className="text-sm font-black text-[#00FFC8] tracking-[0.2em] uppercase">
          TIPSTERS
        </h1>
        <button
          onClick={handleRefresh}
          className="p-1.5 rounded-lg text-[#00FFC8] hover:bg-white/5 active:scale-95 transition-all"
          title="Refresh"
        >
          <RefreshCw className={`w-4 h-4 ${refreshing ? 'animate-spin' : ''}`} />
        </button>
      </div>

      <div className="p-3">
        {tipsters.length === 0 ? (
          <div className="py-24 px-4 text-center">
            <Users className="w-12 h-12 text-[#8899AA] mx-auto mb-3" />
            <p className="text-xs font-black text-[#8899AA] uppercase tracking-wider">
              HAKUNA TIPSTERS BADO
            </p>
            <button
              onClick={handleRefresh}
              className="mt-4 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-xs font-bold text-[#00FFC8]"
            >
              Jaribu Tena
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-2.5">
            {tipsters.map((t) => (
              <TipsterGridCard
                key={t.id}
                tipster={t}
                onSelect={() => setSelectedTipsterId(t.id)}
                onToggleFollow={() => toggleFollowTipster(t.id, !!t.is_following)}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

interface CardProps {
  tipster: Tipster;
  onSelect: () => void;
  onToggleFollow: () => void;
}

const TipsterGridCard: React.FC<CardProps> = ({ tipster, onSelect, onToggleFollow }) => {
  const name = tipster.tipster_name || tipster.name || 'Tipster';
  const verified = !!tipster.tipster_verified;
  const rating = Number(tipster.tipster_rating) || 5.0;
  const winRate = Number(tipster.tipster_success_rate) || 75;
  const isFollowing = !!tipster.is_following;

  return (
    <div
      onClick={onSelect}
      className="p-3 rounded-2xl bg-gradient-to-br from-[#111122] to-[#1A1A2E] border border-white/10 hover:border-white/20 transition-all flex flex-col items-center text-center cursor-pointer shadow-lg active:scale-[0.98]"
    >
      {/* Avatar with circle gradient border */}
      <div className="relative">
        <div className="w-16 h-16 rounded-full p-[2px] bg-gradient-to-tr from-[#00FFC8] to-[#FFD700]">
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
              <span className="text-xl font-black text-[#00FFC8]">
                {name[0]?.toUpperCase() || 'T'}
              </span>
            )}
          </div>
        </div>

        {verified && (
          <div className="absolute bottom-0 right-0 p-0.5 bg-[#1DA1F2] rounded-full border border-[#000010]">
            <Check className="w-2.5 h-2.5 text-white" strokeWidth={3} />
          </div>
        )}
      </div>

      <h3 className="mt-2 text-xs font-black text-[#E8EAF0] truncate w-full">
        {name}
      </h3>

      <div className="mt-0.5 flex items-center gap-1 text-[#FFD700]">
        <Star className="w-3 h-3 fill-[#FFD700]" />
        <span className="text-[11px] font-bold">{rating.toFixed(1)}</span>
      </div>

      <div className="mt-2 flex items-center justify-center gap-1.5 w-full">
        <span className="px-1.5 py-0.5 rounded-full bg-white/5 text-[9px] text-white/70">
          <strong className="text-[#00FFC8]">{tipster.tips_count || 0}</strong> tips
        </span>
        <span className="px-1.5 py-0.5 rounded-full bg-white/5 text-[9px] text-white/70">
          <strong className="text-[#00FFC8]">{winRate.toFixed(0)}%</strong> win
        </span>
      </div>

      <span className="mt-1 text-[10px] text-[#8899AA]">
        {tipster.followers_count || 0} followers
      </span>

      {/* Follow Button */}
      <button
        onClick={(e) => {
          e.stopPropagation();
          onToggleFollow();
        }}
        className={`mt-2.5 w-full py-1.5 px-2 rounded-xl text-[10px] font-black uppercase tracking-wider flex items-center justify-center gap-1 transition-all active:scale-95 ${
          isFollowing
            ? 'bg-[#00C853]/15 text-[#00C853] border border-[#00C853]/30'
            : 'bg-[#00FFC8] text-black hover:bg-[#00e6b4]'
        }`}
      >
        {isFollowing ? (
          <>
            <Check className="w-3 h-3" />
            <span>Following</span>
          </>
        ) : (
          <>
            <UserPlus className="w-3 h-3" />
            <span>Follow</span>
          </>
        )}
      </button>
    </div>
  );
};
