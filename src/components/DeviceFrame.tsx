import React, { useState, useEffect } from 'react';
import { Wifi, Battery, Signal } from 'lucide-react';

interface Props {
  children: React.ReactNode;
  isFramed: boolean;
}

export const DeviceFrame: React.FC<Props> = ({ children, isFramed }) => {
  const [time, setTime] = useState('09:41');

  useEffect(() => {
    const updateTime = () => {
      const d = new Date();
      setTime(
        `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 10000);
    return () => clearInterval(interval);
  }, []);

  if (!isFramed) {
    return <div className="w-full h-full min-h-screen bg-[#000010]">{children}</div>;
  }

  return (
    <div className="flex items-center justify-center min-h-screen p-2 sm:p-6 bg-gradient-to-br from-[#02020a] via-[#050518] to-[#01010a]">
      {/* Smartphone shell */}
      <div className="relative w-full max-w-[410px] h-[870px] max-h-[96vh] rounded-[48px] bg-[#0c0c16] p-3 shadow-[0_25px_80px_rgba(0,0,0,0.85),0_0_40px_rgba(0,255,200,0.12)] border-[4px] border-[#252538] flex flex-col overflow-hidden">
        {/* Dynamic Island / Speaker Notch */}
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-40 h-5 w-28 bg-black rounded-full flex items-center justify-center gap-2 border border-white/10 shadow-inner">
          <div className="w-2.5 h-2.5 rounded-full bg-[#111122] border border-white/20" />
          <div className="w-2 h-2 rounded-full bg-[#00FFC8]/60 blur-[1px]" />
        </div>

        {/* Status Bar */}
        <div className="h-8 px-6 pt-1 flex items-center justify-between text-white/80 text-xs font-semibold z-30 shrink-0 select-none">
          <span className="font-mono text-[11px] tracking-tight">{time}</span>
          <div className="flex items-center gap-1.5 text-white/80">
            <Signal className="w-3.5 h-3.5" />
            <Wifi className="w-3.5 h-3.5" />
            <Battery className="w-4 h-4 text-[#00FFC8]" />
          </div>
        </div>

        {/* Screen Content Container */}
        <div className="relative flex-1 w-full rounded-[38px] overflow-hidden bg-[#000010] flex flex-col">
          <div className="flex-1 overflow-y-auto overflow-x-hidden relative scrollbar-thin scrollbar-thumb-white/10">
            {children}
          </div>

          {/* Android / iOS Home Indicator Bar */}
          <div className="h-4 w-full bg-[#000010] flex items-center justify-center shrink-0 z-40">
            <div className="w-32 h-1 bg-white/30 rounded-full" />
          </div>
        </div>
      </div>
    </div>
  );
};
