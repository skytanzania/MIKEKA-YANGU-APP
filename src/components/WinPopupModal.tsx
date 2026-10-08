import React, { useState } from 'react';
import { useApp } from '../context/AppContext';

export const WinPopupModal: React.FC = () => {
  const { activeWinSlip, closeWinPopup, dismissPopup } = useApp();
  const [askDismissPrompt, setAskDismissPrompt] = useState(false);

  if (!activeWinSlip) return null;

  const handleFinish = () => {
    setAskDismissPrompt(true);
  };

  const confirmDismiss = async (shouldDismiss: boolean) => {
    if (shouldDismiss) {
      await dismissPopup('win_popup');
    }
    setAskDismissPrompt(false);
    closeWinPopup();
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
      {!askDismissPrompt ? (
        <div className="w-full max-w-sm rounded-[24px] p-6 bg-gradient-to-br from-[#0A1A00] to-[#1A3A00] border-[3px] border-[#00C853] shadow-[0_0_50px_rgba(0,200,83,0.4)] text-center animate-scale-up">
          <div className="text-6xl mb-2 select-none animate-bounce">🏆</div>

          <h2 className="text-2xl font-black text-[#00C853] tracking-[0.1em] uppercase drop-shadow-[0_2px_10px_rgba(0,200,83,0.5)]">
            UMESHINDA!
          </h2>

          <p className="mt-1 text-xs font-bold text-white tracking-wide">
            MKEKA WAKO UMESHINDAAA! 🎯
          </p>

          <div className="mt-5 p-3 rounded-xl bg-black/40 border border-[#00C853]/25 divide-y divide-white/5 text-left text-xs space-y-2">
            <div className="flex items-center justify-between pb-1.5">
              <span className="text-white/60">Booking Code</span>
              <span className="font-bold text-[#00C853] font-mono tracking-wider">
                {activeWinSlip.booking_code || '---'}
              </span>
            </div>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-white/60">Odds</span>
              <span className="font-bold text-[#00C853]">
                {activeWinSlip.odds || '--'}
              </span>
            </div>
            <div className="flex items-center justify-between py-1.5">
              <span className="text-white/60">Kampuni</span>
              <span className="font-bold text-[#00C853]">
                {activeWinSlip.company_name || '--'}
              </span>
            </div>
            <div className="flex items-center justify-between pt-1.5">
              <span className="text-white/60">Tarehe</span>
              <span className="font-bold text-[#00C853]">
                {activeWinSlip.created_date || new Date().toISOString().split('T')[0]}
              </span>
            </div>
          </div>

          <p className="mt-4 text-[11px] text-white/75 leading-relaxed">
            Hongera sana! Endelea kufuatilia mikeka yetu ya uhakika! 💪🔥
          </p>

          <button
            onClick={handleFinish}
            className="mt-5 w-full py-3 rounded-xl bg-[#00C853] hover:bg-[#00b047] text-black font-black text-xs uppercase tracking-wider shadow-lg active:scale-95 transition-all"
          >
            ASANTE SANA!
          </button>
        </div>
      ) : (
        <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/20 p-5 shadow-2xl animate-scale-up text-center">
          <h3 className="text-sm font-black text-white uppercase tracking-wider">
            Onyesho la ushindi
          </h3>
          <p className="mt-2 text-xs text-[#8899AA] leading-relaxed">
            Usionyeshe tena ujumbe huu wa ushindi kwenye vifaa vyako?
          </p>

          <div className="mt-5 flex items-center justify-end gap-2">
            <button
              onClick={() => confirmDismiss(false)}
              className="px-4 py-2 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
            >
              HAPANA
            </button>
            <button
              onClick={() => confirmDismiss(true)}
              className="px-4 py-2 rounded-xl text-xs font-black bg-[#00FFC8] text-black hover:bg-[#00e6b4]"
            >
              NDIYO
            </button>
          </div>
        </div>
      )}
    </div>
  );
};
