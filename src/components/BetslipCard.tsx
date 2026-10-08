import React, { useState } from 'react';
import { Betslip } from '../types/mikeka';
import { Lock, Copy, Check, Clock, TrendingUp, Cpu } from 'lucide-react';
import { useApp } from '../context/AppContext';

interface Props {
  slip: Betslip;
  isBlurred?: boolean;
  isSystemGenerated?: boolean;
}

export const BetslipCard: React.FC<Props> = ({ slip, isBlurred = false, isSystemGenerated = false }) => {
  const { showSnack } = useApp();
  const [copied, setCopied] = useState(false);

  const bookingCode = slip.booking_code || '---';
  const maskedCode = isBlurred
    ? bookingCode.length > 3
      ? `${bookingCode.substring(0, 3)}***`
      : '***'
    : bookingCode;

  const handleCopy = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (isBlurred) return;
    navigator.clipboard.writeText(bookingCode);
    setCopied(true);
    showSnack('Booking code imenakiliwa!');
    setTimeout(() => setCopied(false), 2000);
  };

  const resultStatus = slip.result_status || 'pending';

  return (
    <div className="mb-3.5 bg-[#111122] rounded-xl border border-white/10 overflow-hidden shadow-lg transition-all hover:border-white/20">
      {/* Header */}
      <div className="px-3.5 pt-3 flex items-center justify-between">
        <div className="flex items-center gap-2 overflow-hidden">
          {slip.logo_url && (
            <div className="w-6 h-6 p-0.5 bg-white/10 rounded-md flex items-center justify-center shrink-0">
              <img
                src={slip.logo_url}
                alt={slip.company_name || 'Logo'}
                className="w-full h-full object-contain"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                }}
              />
            </div>
          )}
          {slip.company_name && (
            <span className="text-xs font-black text-[#00FFC8] truncate uppercase tracking-wider">
              {slip.company_name}
            </span>
          )}
        </div>

        {slip.package_type && (
          <span className="px-2 py-0.5 rounded-full text-[9px] font-black uppercase bg-[#FFD700]/15 text-[#FFD700] border border-[#FFD700]/30 tracking-wider">
            {slip.package_type}
          </span>
        )}
      </div>

      {/* Booking Code Box */}
      <div className="px-3.5 pt-2.5">
        <div className="relative w-full py-3.5 bg-[#0A0A1A] rounded-lg border border-[#00FFC8]/30 flex items-center justify-center overflow-hidden">
          <span
            className={`text-2xl font-black tracking-[0.3em] select-all ${
              isBlurred ? 'text-[#FFD700] filter blur-[3px]' : 'text-[#00FFC8]'
            }`}
          >
            {maskedCode}
          </span>

          {isBlurred && (
            <div className="absolute inset-0 bg-black/60 backdrop-blur-[2px] flex items-center justify-center gap-2">
              <Lock className="w-5 h-5 text-[#00FFC8]" />
              <span className="text-[11px] font-extrabold text-[#00FFC8] tracking-widest uppercase">
                FUNGUA MKEKA
              </span>
            </div>
          )}
        </div>
      </div>

      {/* Match Details */}
      {!isBlurred && slip.match_details && (
        <div className="px-3.5 pt-2.5">
          <p className="text-xs text-white/75 leading-relaxed bg-white/[0.02] p-2 rounded-md border border-white/5">
            {slip.match_details}
          </p>
        </div>
      )}

      {/* Badges */}
      <div className="px-3.5 pt-2.5 flex flex-wrap gap-1.5 items-center">
        {slip.odds && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black bg-[#FFD700]/15 text-[#FFD700] border border-[#FFD700]/35">
            <TrendingUp className="w-3 h-3 text-[#FFD700]" />
            ODDS: {slip.odds}
          </span>
        )}

        {resultStatus === 'won' ? (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black bg-[#00C853]/15 text-[#00C853] border border-[#00C853]/35">
            <Check className="w-3 h-3" />
            WON
          </span>
        ) : resultStatus === 'lost' ? (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black bg-[#FF0055]/15 text-[#FF0055] border border-[#FF0055]/35">
            LOST
          </span>
        ) : (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black bg-[#FF6B00]/15 text-[#FF6B00] border border-[#FF6B00]/35">
            <Clock className="w-3 h-3" />
            PENDING
          </span>
        )}

        {(isSystemGenerated || slip.slip_type === 'system') && (
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-black bg-[#00B4FF]/15 text-[#00B4FF] border border-[#00B4FF]/35">
            <Cpu className="w-3 h-3" />
            SYSTEM
          </span>
        )}
      </div>

      {/* Footer */}
      <div className="px-3.5 py-3 flex items-center justify-between text-white/50 text-[11px] border-t border-white/5 mt-2">
        <div className="flex items-center gap-1 truncate">
          {slip.validity_time ? (
            <>
              <Clock className="w-3 h-3 text-[#8899AA]" />
              <span className="text-[#8899AA] text-[10px]">
                Expires: {slip.validity_time}
              </span>
            </>
          ) : (
            <span className="text-[#8899AA] text-[10px]">Mkeka wa Leo</span>
          )}
        </div>

        {!isBlurred && (
          <button
            onClick={handleCopy}
            className="flex items-center gap-1 px-2.5 py-1 rounded-md text-[#00FFC8] hover:bg-[#00FFC8]/10 transition-colors text-xs font-bold"
          >
            {copied ? (
              <>
                <Check className="w-3.5 h-3.5 text-[#00C853]" />
                <span className="text-[#00C853]">Copied!</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5" />
                <span>Copy</span>
              </>
            )}
          </button>
        )}
      </div>
    </div>
  );
};
