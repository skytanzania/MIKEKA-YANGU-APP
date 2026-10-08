import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { AlertTriangle, AlertOctagon } from 'lucide-react';

export const WarningPopupModal: React.FC = () => {
  const { activeWarning, closeWarningPopup, dismissPopup } = useApp();
  const [askDismissPrompt, setAskDismissPrompt] = useState(false);

  if (!activeWarning) return null;

  const isHigh = activeWarning.severity === 'high' || activeWarning.severity === 'critical';

  const confirmDismiss = async (shouldDismiss: boolean) => {
    if (shouldDismiss) {
      await dismissPopup('warning_popup');
    }
    setAskDismissPrompt(false);
    closeWarningPopup();
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
      {!askDismissPrompt ? (
        <div
          className={`w-full max-w-sm rounded-[22px] p-6 text-center border-2 animate-scale-up ${
            isHigh
              ? 'bg-gradient-to-b from-[#2A0505] to-[#1A0000] border-[#FF0055]'
              : 'bg-gradient-to-b from-[#2A1A00] to-[#1A0A00] border-[#FF6B00]'
          }`}
        >
          {isHigh ? (
            <AlertOctagon className="w-14 h-14 text-[#FF0055] mx-auto mb-2" />
          ) : (
            <AlertTriangle className="w-14 h-14 text-[#FF6B00] mx-auto mb-2" />
          )}

          <h3
            className={`text-base font-black tracking-wider uppercase ${
              isHigh ? 'text-[#FF0055]' : 'text-[#FF6B00]'
            }`}
          >
            {isHigh ? 'TAHADHARI KUBWA!' : 'TAHADHARI YA AKAUNTI'}
          </h3>

          <p className="mt-3 text-xs text-white/80 leading-relaxed">
            {activeWarning.message}
          </p>

          <button
            onClick={() => setAskDismissPrompt(true)}
            className={`mt-5 w-full py-3 rounded-xl font-black text-xs uppercase tracking-wider text-white shadow-lg active:scale-95 transition-all ${
              isHigh ? 'bg-[#FF0055] hover:bg-[#e0004c]' : 'bg-[#FF6B00] hover:bg-[#e65c00]'
            }`}
          >
            NIMEKUELEWA
          </button>
        </div>
      ) : (
        <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/20 p-5 shadow-2xl animate-scale-up text-center">
          <h3 className="text-sm font-black text-white uppercase tracking-wider">
            Onyesho la tahadhari
          </h3>
          <p className="mt-2 text-xs text-[#8899AA] leading-relaxed">
            Usionyeshe tena ujumbe huu wa tahadhari?
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
