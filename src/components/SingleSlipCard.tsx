import React from 'react';
import { SingleSlip } from '../types/mikeka';
import { Lock, ShoppingCart, TrendingUp, CheckCircle } from 'lucide-react';

interface Props {
  slip: SingleSlip;
  purchased?: boolean;
  onBuy?: () => void;
}

export const SingleSlipCard: React.FC<Props> = ({ slip, purchased = false, onBuy }) => {
  const price = Number(slip.price) || 3000;
  const bookingCode = slip.booking_code || '---';
  const maskedCode = purchased
    ? bookingCode
    : bookingCode.length > 3
    ? `${bookingCode.substring(0, 3)}***`
    : '***';

  const tipsterName = slip.tipster_name || slip.tipster_user_name || 'Tipster';
  const tipsterAvatar = slip.tipster_avatar;

  return (
    <div
      className={`mb-3.5 p-3.5 rounded-xl border bg-[#111122] transition-all ${
        purchased
          ? 'border-[#00C853]/35 shadow-[0_4px_20px_rgba(0,200,83,0.08)]'
          : 'border-[#FFD700]/30 hover:border-[#FFD700]/50'
      }`}
    >
      {/* Top company and status */}
      <div className="flex items-center justify-between gap-2">
        <div className="flex items-center gap-2 overflow-hidden">
          {slip.logo_url && (
            <img
              src={slip.logo_url}
              alt={slip.company_name || 'Logo'}
              className="w-5 h-5 object-contain rounded"
              onError={(e) => {
                (e.target as HTMLElement).style.display = 'none';
              }}
            />
          )}
          {slip.company_name && (
            <span className="text-xs font-black text-[#00FFC8] uppercase tracking-wider">
              {slip.company_name}
            </span>
          )}
        </div>

        {purchased ? (
          <span className="px-2.5 py-0.5 rounded-full text-[10px] font-black uppercase bg-[#00C853]/15 text-[#00C853] border border-[#00C853]/30 tracking-wider flex items-center gap-1">
            <CheckCircle className="w-3 h-3" />
            UMELIPIA
          </span>
        ) : (
          <span className="px-2.5 py-0.5 rounded-full text-xs font-black bg-[#FFD700]/15 text-[#FFD700] border border-[#FFD700]/40">
            {price.toLocaleString()}/=
          </span>
        )}
      </div>

      {/* Tipster Author Info */}
      {tipsterName && (
        <div className="mt-2.5 flex items-center gap-2.5 p-2 rounded-lg bg-white/[0.03]">
          <div className="w-8 h-8 rounded-full bg-[#FFD700]/20 border border-[#FFD700]/40 flex items-center justify-center overflow-hidden shrink-0">
            {tipsterAvatar && tipsterAvatar.startsWith('http') ? (
              <img
                src={tipsterAvatar}
                alt={tipsterName}
                className="w-full h-full object-cover"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                }}
              />
            ) : (
              <span className="text-xs font-black text-[#FFD700]">
                {tipsterName[0]?.toUpperCase() || 'T'}
              </span>
            )}
          </div>
          <div className="flex-1 min-w-0">
            <span className="block text-[10px] text-[#FFD700] font-bold uppercase tracking-wider">
              Mkeka wa Tipster
            </span>
            <span className="block text-xs font-black text-white truncate">
              {tipsterName}
            </span>
          </div>
        </div>
      )}

      {/* Booking Code Display */}
      <div className="mt-2.5 relative">
        <div
          className={`w-full py-3 bg-[#0A0A1A] rounded-lg border flex items-center justify-center ${
            purchased ? 'border-[#00C853]/40' : 'border-[#FFD700]/30'
          }`}
        >
          <span
            className={`text-xl font-black tracking-[0.25em] ${
              purchased ? 'text-[#00FFC8]' : 'text-[#FFD700] filter blur-[2px]'
            }`}
          >
            {maskedCode}
          </span>
        </div>

        {!purchased && (
          <div className="absolute inset-0 bg-black/50 backdrop-blur-[2px] rounded-lg flex items-center justify-center gap-1.5">
            <Lock className="w-5 h-5 text-[#FFD700]" />
            <span className="text-xs font-black text-[#FFD700] tracking-wider uppercase">
              LIPIA KUONA CODE
            </span>
          </div>
        )}
      </div>

      {/* Match details */}
      {slip.match_details && (
        <div className="mt-2 text-xs text-white/70 leading-relaxed">
          {purchased ? (
            <p className="bg-white/[0.02] p-2 rounded border border-white/5">{slip.match_details}</p>
          ) : (
            <p className="text-white/50 text-[11px] italic">
              {slip.match_details.length > 35
                ? `${slip.match_details.substring(0, 35)}... [LIPIA KUONA ZAIDI]`
                : slip.match_details}
            </p>
          )}
        </div>
      )}

      {/* Odds badge */}
      {slip.odds && (
        <div className="mt-2 flex items-center gap-1 text-[11px] font-black text-[#FFD700]">
          <TrendingUp className="w-3.5 h-3.5 text-[#FFD700]" />
          <span>ODDS: {slip.odds}</span>
        </div>
      )}

      {/* Purchase Button */}
      {!purchased && onBuy && (
        <button
          onClick={onBuy}
          className="mt-3 w-full py-2.5 px-4 rounded-xl bg-[#FFD700] hover:bg-[#FFE033] active:scale-[0.98] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg transition-all"
        >
          <ShoppingCart className="w-4 h-4" />
          <span>LIPIA {price.toLocaleString()}/=</span>
        </button>
      )}
    </div>
  );
};
