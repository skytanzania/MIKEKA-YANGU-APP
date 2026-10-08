import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  User,
  Crown,
  Phone,
  History,
  Trophy,
  LogOut,
  AlertTriangle,
  ChevronRight,
  Star,
  LogIn,
  Smartphone,
} from 'lucide-react';
import { ChangePhoneModal } from './ChangePhoneModal';
import { PaymentsSheet } from './PaymentsSheet';
import { GenerateApkModal } from './GenerateApkModal';

export const ProfileTab: React.FC = () => {
  const {
    loggedIn,
    user,
    displayPhone,
    isTipster,
    subscription,
    openLoginModal,
    openPackagesModal,
    logout,
  } = useApp();

  const [isChangePhoneOpen, setIsChangePhoneOpen] = useState(false);
  const [isPaymentsOpen, setIsPaymentsOpen] = useState(false);
  const [isApkModalOpen, setIsApkModalOpen] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);

  // Remaining time calculation
  const getRemainingTime = () => {
    if (!subscription?.end_date) return '--';
    const end = new Date(subscription.end_date);
    const now = new Date();
    const diffMs = end.getTime() - now.getTime();
    if (diffMs <= 0) return 'IMEISHA';

    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor((diffMs / (1000 * 60 * 60)) % 24);
    const diffMins = Math.floor((diffMs / (1000 * 60)) % 60);

    if (diffDays >= 1) return `${diffDays}siku ${diffHours}h ${diffMins}m`;
    if (diffHours >= 1) return `${diffHours}h ${diffMins}m`;
    return `${diffMins} dakika`;
  };

  const formatEndDate = () => {
    if (!subscription?.end_date) return '';
    try {
      const d = new Date(subscription.end_date);
      return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()} ${String(
        d.getHours()
      ).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    } catch (_) {
      return subscription.end_date;
    }
  };

  return (
    <div className="min-h-full pb-20 bg-[#000010] text-[#E8EAF0]">
      {/* App Bar */}
      <div className="sticky top-0 z-20 bg-[#000010]/95 backdrop-blur border-b border-white/10 px-4 py-3 flex items-center justify-between">
        <div className="w-8" />
        <h1 className="text-sm font-black text-[#00FFC8] tracking-[0.2em] uppercase">
          PROFILE
        </h1>
        {loggedIn ? (
          <button
            onClick={() => setShowLogoutConfirm(true)}
            className="p-1.5 rounded-lg text-[#FF0055] hover:bg-white/5 active:scale-95 transition-all"
            title="Toka"
          >
            <LogOut className="w-4 h-4" />
          </button>
        ) : (
          <div className="w-8" />
        )}
      </div>

      <div className="p-4 space-y-4">
        {/* Guest View */}
        {!loggedIn ? (
          <div className="py-16 px-4 flex flex-col items-center text-center">
            <div className="w-20 h-20 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-[#8899AA] mb-4">
              <User className="w-10 h-10" />
            </div>

            <h2 className="text-lg font-black text-[#E8EAF0]">
              Karibu Mikeka App
            </h2>
            <p className="mt-2 text-xs text-[#8899AA] leading-relaxed max-w-xs">
              Ingia au jisajili ili kuweza kununua mikeka, kufuata tipsters, na kupata huduma zote.
            </p>

            <button
              onClick={openLoginModal}
              className="mt-6 w-full py-3 px-6 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg hover:bg-[#00e6b4] active:scale-[0.98] transition-all"
            >
              <LogIn className="w-4 h-4" />
              <span>INGIA / JISAJILI</span>
            </button>
          </div>
        ) : (
          /* Logged In View */
          <>
            {/* User Profile Card */}
            <div className="p-5 rounded-2xl bg-gradient-to-r from-[#00FFC8]/10 to-[#00B4FF]/10 border border-[#00FFC8]/25 shadow-lg flex flex-col items-center text-center">
              <div className="w-16 h-16 rounded-full bg-[#00FFC8]/15 border border-[#00FFC8]/40 flex items-center justify-center text-[#00FFC8] mb-2 shadow-inner">
                <User className="w-8 h-8" />
              </div>

              <div className="text-xl font-black text-[#00FFC8] tracking-wider">
                {displayPhone || user?.phone_number || 'Mtumiaji'}
              </div>

              <div className="text-xs text-[#8899AA] mt-0.5">
                {user?.name || 'Customer'}
              </div>

              {isTipster && (
                <div className="mt-2 px-3 py-0.5 rounded-full bg-[#FFD700]/15 border border-[#FFD700]/30 text-[10px] font-black text-[#FFD700] uppercase tracking-wider flex items-center gap-1">
                  <Star className="w-3 h-3 fill-[#FFD700]" />
                  <span>TIPSTER</span>
                </div>
              )}
            </div>

            {/* Subscription Card */}
            {subscription ? (
              <div className="p-4 rounded-xl bg-[#111122] border border-[#00FFC8]/30 shadow-lg">
                <div className="flex items-center gap-2">
                  <Crown className="w-5 h-5 text-[#FFD700]" />
                  <span className="text-xs font-black text-[#FFD700] uppercase tracking-wider">
                    KIFURUSHI: {subscription.package_type.toUpperCase()}
                  </span>
                </div>

                <div className="mt-2.5 text-sm font-black text-[#00FFC8]">
                  Inabaki: {getRemainingTime()}
                </div>

                {subscription.end_date && (
                  <div className="mt-0.5 text-[11px] text-[#8899AA]">
                    Inaisha: {formatEndDate()}
                  </div>
                )}
              </div>
            ) : (
              <div className="p-4 rounded-xl bg-[#111122] border border-white/10 shadow-lg flex flex-col items-center text-center">
                <AlertTriangle className="w-8 h-8 text-[#FF6B00] mb-1" />
                <span className="text-xs font-black text-[#FF6B00] uppercase tracking-wider">
                  HAKUNA KIFURUSHI
                </span>
                <p className="mt-1 text-xs text-[#8899AA]">
                  Huna kifurushi kinachoendelea kwa sasa.
                </p>
                <button
                  onClick={() => openPackagesModal()}
                  className="mt-3 w-full py-2.5 px-4 rounded-xl bg-[#00FFC8] text-black font-black text-xs uppercase tracking-wider shadow"
                >
                  LIPIA SASA
                </button>
              </div>
            )}

            {/* Action Tiles */}
            <div className="space-y-2 pt-2">
              <button
                onClick={() => setIsApkModalOpen(true)}
                className="w-full p-3.5 rounded-xl bg-gradient-to-r from-[#00FFC8]/10 to-[#00B4FF]/10 border border-[#00FFC8]/30 hover:border-[#00FFC8]/60 transition-all flex items-center justify-between group active:scale-[0.99]"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#00FFC8]/20 text-[#00FFC8]">
                    <Smartphone className="w-4 h-4" />
                  </div>
                  <div className="text-left">
                    <span className="text-xs font-black text-[#00FFC8] block">
                      ⚡ Tengeneza / Sakinisha APK
                    </span>
                    <span className="text-[10px] text-[#8899AA] block">
                      Pakua App kwenye Simu au tengeneza APK ya Android
                    </span>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-[#00FFC8] group-hover:translate-x-0.5 transition-transform" />
              </button>

              <button
                onClick={() => setIsChangePhoneOpen(true)}
                className="w-full p-3.5 rounded-xl bg-[#111122] border border-white/10 hover:border-white/20 transition-all flex items-center justify-between group active:scale-[0.99]"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#00FFC8]/10 text-[#00FFC8]">
                    <Phone className="w-4 h-4" />
                  </div>
                  <span className="text-xs font-bold text-[#E8EAF0]">
                    Badilisha Namba
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-[#8899AA] group-hover:text-white transition-colors" />
              </button>

              <button
                onClick={() => setIsPaymentsOpen(true)}
                className="w-full p-3.5 rounded-xl bg-[#111122] border border-white/10 hover:border-white/20 transition-all flex items-center justify-between group active:scale-[0.99]"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#00B4FF]/10 text-[#00B4FF]">
                    <History className="w-4 h-4" />
                  </div>
                  <span className="text-xs font-bold text-[#E8EAF0]">
                    Historia ya Malipo
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-[#8899AA] group-hover:text-white transition-colors" />
              </button>

              <a
                href="https://mikekaapp.co.tz/users.php"
                target="_blank"
                rel="noreferrer"
                className="w-full p-3.5 rounded-xl bg-[#111122] border border-white/10 hover:border-white/20 transition-all flex items-center justify-between group active:scale-[0.99]"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#FFD700]/10 text-[#FFD700]">
                    <Trophy className="w-4 h-4" />
                  </div>
                  <span className="text-xs font-bold text-[#E8EAF0]">
                    Washindi
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-[#8899AA] group-hover:text-white transition-colors" />
              </a>

              <button
                onClick={() => setShowLogoutConfirm(true)}
                className="w-full p-3.5 rounded-xl bg-[#111122] border border-[#FF0055]/30 hover:border-[#FF0055]/60 transition-all flex items-center justify-between group active:scale-[0.99]"
              >
                <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-[#FF0055]/10 text-[#FF0055]">
                    <LogOut className="w-4 h-4" />
                  </div>
                  <span className="text-xs font-bold text-[#FF0055]">
                    Toka
                  </span>
                </div>
                <ChevronRight className="w-4 h-4 text-[#FF0055]" />
              </button>
            </div>
          </>
        )}
      </div>

      {/* Logout confirmation dialog */}
      {showLogoutConfirm && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-sm rounded-2xl bg-[#111122] border border-white/15 p-5 shadow-2xl">
            <h3 className="text-sm font-black text-white uppercase tracking-wider">
              Toka?
            </h3>
            <p className="mt-2 text-xs text-[#8899AA] leading-relaxed">
              Una uhakika unataka kutoka kwenye akaunti yako ya Mikeka App?
            </p>
            <div className="mt-5 flex items-center justify-end gap-2">
              <button
                onClick={() => setShowLogoutConfirm(false)}
                className="px-4 py-2 rounded-xl text-xs font-bold text-[#8899AA] hover:bg-white/5"
              >
                HAPANA
              </button>
              <button
                onClick={() => {
                  setShowLogoutConfirm(false);
                  logout();
                }}
                className="px-4 py-2 rounded-xl text-xs font-black bg-[#FF0055] text-white hover:bg-[#e0004c]"
              >
                NDIYO
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Change phone modal */}
      {isChangePhoneOpen && (
        <ChangePhoneModal onClose={() => setIsChangePhoneOpen(false)} />
      )}

      {/* Payments history sheet */}
      {isPaymentsOpen && (
        <PaymentsSheet onClose={() => setIsPaymentsOpen(false)} />
      )}

      {/* Generate APK Modal */}
      {isApkModalOpen && (
        <GenerateApkModal onClose={() => setIsApkModalOpen(false)} />
      )}
    </div>
  );
};
