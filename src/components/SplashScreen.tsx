import React from 'react';
import { Dices, Loader2 } from 'lucide-react';

interface Props {
  onFinish?: () => void;
}

export const SplashScreen: React.FC<Props> = () => {
  return (
    <div
      className="fixed inset-0 z-50 flex flex-col items-center justify-center select-none"
      style={{
        background: 'radial-gradient(circle at center, #001A1A 0%, #000010 80%)',
      }}
    >
      <div className="flex flex-col items-center animate-fade-in">
        <div className="relative">
          <div className="absolute inset-0 bg-[#00FFC8]/20 blur-2xl rounded-full scale-150 animate-pulse" />
          <div className="relative w-24 h-24 rounded-2xl bg-gradient-to-br from-[#00FFC8] to-[#00B4FF] flex items-center justify-center shadow-[0_0_50px_rgba(0,255,200,0.4)]">
            <Dices className="w-14 h-14 text-[#000010]" strokeWidth={2.2} />
          </div>
        </div>

        <h1 className="mt-6 text-3xl font-black text-[#00FFC8] tracking-[0.25em] drop-shadow-[0_2px_12px_rgba(0,255,200,0.5)]">
          MIKEKA APP
        </h1>
        <p className="mt-1 text-xs text-[#8899AA] tracking-wider font-medium">
          Mikeka ya Leo Tanzania
        </p>

        <div className="mt-10 flex items-center gap-2">
          <Loader2 className="w-6 h-6 text-[#00FFC8] animate-spin" />
          <span className="text-xs text-white/50 tracking-widest font-mono uppercase">
            Inapakia...
          </span>
        </div>
      </div>
    </div>
  );
};
