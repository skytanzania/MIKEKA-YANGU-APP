import React from 'react';
import { useApp } from '../context/AppContext';
import { CheckCircle2, Clock, X, AlertCircle } from 'lucide-react';

interface Props {
  onClose: () => void;
}

export const PaymentsSheet: React.FC<Props> = ({ onClose }) => {
  const { payments } = useApp();

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-end justify-center">
      <div className="w-full max-w-md rounded-t-[24px] bg-[#111122] border-t border-white/15 p-5 shadow-2xl max-h-[80vh] flex flex-col animate-slide-up">
        {/* Handle bar */}
        <div className="w-10 h-1 bg-[#8899AA]/40 rounded-full mx-auto mb-3" />

        <div className="flex items-center justify-between pb-3 border-b border-white/5">
          <h3 className="text-sm font-black text-[#00FFC8] tracking-wider uppercase">
            HISTORIA YA MALIPO
          </h3>
          <button
            onClick={onClose}
            className="p-1 text-[#8899AA] hover:text-white rounded-lg hover:bg-white/5"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="overflow-y-auto flex-1 py-3 space-y-2">
          {payments.length === 0 ? (
            <div className="py-12 text-center">
              <AlertCircle className="w-10 h-10 text-[#8899AA] mx-auto mb-2 opacity-50" />
              <p className="text-xs text-[#8899AA]">Hakuna malipo bado</p>
            </div>
          ) : (
            payments.map((p, idx) => {
              const isCompleted = p.payment_status === 'completed';
              return (
                <div
                  key={p.id || idx}
                  className="p-3 rounded-xl bg-[#0A0A1A] border border-white/5 flex items-center justify-between gap-3"
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`p-2 rounded-lg ${
                        isCompleted
                          ? 'bg-[#00C853]/15 text-[#00C853]'
                          : 'bg-[#FF6B00]/15 text-[#FF6B00]'
                      }`}
                    >
                      {isCompleted ? (
                        <CheckCircle2 className="w-5 h-5" />
                      ) : (
                        <Clock className="w-5 h-5" />
                      )}
                    </div>

                    <div>
                      <span className="text-sm font-black text-white block">
                        TSh {Number(p.amount).toLocaleString()}
                      </span>
                      <span className="text-[10px] text-[#8899AA] block">
                        {p.package_type?.toUpperCase()} • {p.created_at || 'Leo'}
                      </span>
                    </div>
                  </div>

                  <span
                    className={`text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full ${
                      isCompleted
                        ? 'bg-[#00C853]/15 text-[#00C853] border border-[#00C853]/30'
                        : 'bg-[#FF6B00]/15 text-[#FF6B00] border border-[#FF6B00]/30'
                    }`}
                  >
                    {p.payment_status}
                  </span>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
};
