import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { ApiClient } from '../services/api';
import { User, Subscription, Payment, Tipster, Betslip, SingleSlip, ApiResponse } from '../types/mikeka';

interface AppContextType {
  loggedIn: boolean;
  isTipster: boolean;
  isSubscribed: boolean;
  user: User | null;
  subscription: Subscription | null;
  payments: Payment[];
  todaysSlips: Betslip[];
  allSlips: Betslip[];
  bettingCompanies: any[];
  tipsters: Tipster[];
  followedTipsters: any[];
  singleSlips: SingleSlip[];
  purchasedSingleSlips: SingleSlip[];
  dismissedPopups: string[];
  displayPhone: string | null;
  activeWarning: { message: string; severity: 'low' | 'medium' | 'high' | 'critical' } | null;
  activeWinSlip: Betslip | null;
  sessionInvalidReason: string | null;
  isSessionBanned: boolean;

  // Actions
  applyUserData: (data: Record<string, any>) => void;
  setLoggedOut: () => void;
  isPopupDismissed: (type: string) => boolean;
  dismissPopup: (type: string) => Promise<void>;
  refreshUserData: () => Promise<void>;
  loadTipsters: () => Promise<void>;
  loadSingleSlips: () => Promise<void>;
  toggleFollowTipster: (tipsterId: number, current: boolean) => Promise<{ success: boolean; message: string }>;
  logout: () => Promise<void>;
  
  // UI triggers
  openLoginModal: () => void;
  closeLoginModal: () => void;
  isLoginModalOpen: boolean;

  openPackagesModal: (preselectedPackage?: string) => void;
  closePackagesModal: () => void;
  isPackagesModalOpen: boolean;
  selectedPackageForPayment: string | null;

  openSingleSlipModal: (slip: SingleSlip) => void;
  closeSingleSlipModal: () => void;
  selectedSlipForPayment: SingleSlip | null;

  showWinPopupManually: (slip?: Betslip) => void;
  closeWinPopup: () => void;

  showWarningPopupManually: (message?: string, severity?: 'medium' | 'high') => void;
  closeWarningPopup: () => void;

  // Toast / Snackbar
  snack: { message: string; isError: boolean } | null;
  showSnack: (message: string, isError?: boolean) => void;
}

const AppContext = createContext<AppContextType | null>(null);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [loggedIn, setLoggedIn] = useState(false);
  const [isTipster, setIsTipster] = useState(false);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [todaysSlips, setTodaysSlips] = useState<Betslip[]>([]);
  const [allSlips, setAllSlips] = useState<Betslip[]>([]);
  const [bettingCompanies, setBettingCompanies] = useState<any[]>([]);
  const [tipsters, setTipsters] = useState<Tipster[]>([]);
  const [followedTipsters, setFollowedTipsters] = useState<any[]>([]);
  const [singleSlips, setSingleSlips] = useState<SingleSlip[]>([]);
  const [purchasedSingleSlips, setPurchasedSingleSlips] = useState<SingleSlip[]>([]);
  const [dismissedPopups, setDismissedPopups] = useState<string[]>([]);
  const [displayPhone, setDisplayPhone] = useState<string | null>(null);

  const [activeWarning, setActiveWarning] = useState<{ message: string; severity: 'low' | 'medium' | 'high' | 'critical' } | null>(null);
  const [activeWinSlip, setActiveWinSlip] = useState<Betslip | null>(null);
  const [sessionInvalidReason, setSessionInvalidReason] = useState<string | null>(null);
  const [isSessionBanned, setIsSessionBanned] = useState(false);

  const [isLoginModalOpen, setIsLoginModalOpen] = useState(false);
  const [isPackagesModalOpen, setIsPackagesModalOpen] = useState(false);
  const [selectedPackageForPayment, setSelectedPackageForPayment] = useState<string | null>(null);
  const [selectedSlipForPayment, setSelectedSlipForPayment] = useState<SingleSlip | null>(null);

  const [snack, setSnack] = useState<{ message: string; isError: boolean } | null>(null);

  const showSnack = useCallback((message: string, isError = false) => {
    setSnack({ message, isError });
    setTimeout(() => {
      setSnack((current) => (current?.message === message ? null : current));
    }, isError ? 4000 : 3000);
  }, []);

  const parseDismissed = (raw: any): string[] => {
    if (!raw) return [];
    try {
      if (Array.isArray(raw)) return raw.map(String);
      const parsed = JSON.parse(String(raw));
      if (Array.isArray(parsed)) return parsed.map(String);
    } catch (_) {}
    return [];
  };

  const applyUserData = useCallback((d: Record<string, any>) => {
    const u = d.user ? (d.user as User) : null;
    setUser(u);
    setDisplayPhone(d.display_phone || (u?.phone_number ?? null));
    setSubscription(d.subscription ? (d.subscription as Subscription) : null);
    setPayments(Array.isArray(d.payments) ? d.payments : []);
    setTodaysSlips(Array.isArray(d.todays_slips) ? d.todays_slips : []);
    setAllSlips(Array.isArray(d.all_slips) ? d.all_slips : []);
    setBettingCompanies(Array.isArray(d.betting_companies) ? d.betting_companies : []);
    if (Array.isArray(d.tipsters) && d.tipsters.length > 0) {
      setTipsters(d.tipsters);
    }
    setFollowedTipsters(Array.isArray(d.followed_tipsters) ? d.followed_tipsters : []);
    setPurchasedSingleSlips(Array.isArray(d.purchased_single_slips) ? d.purchased_single_slips : []);
    setIsTipster(d.is_tipster === true);
    setIsSubscribed(d.is_subscribed === true);
    setDismissedPopups(parseDismissed(u?.dismissed_popups));
    setLoggedIn(true);
  }, []);

  const setLoggedOut = useCallback(() => {
    setLoggedIn(false);
    setIsTipster(false);
    setIsSubscribed(false);
    setUser(null);
    setSubscription(null);
    setPayments([]);
    setTodaysSlips([]);
    allSlips;
    setFollowedTipsters([]);
    setPurchasedSingleSlips([]);
    setDismissedPopups([]);
    setDisplayPhone(null);
  }, []);

  const isPopupDismissed = useCallback(
    (type: string) => dismissedPopups.includes(type),
    [dismissedPopups]
  );

  const dismissPopup = useCallback(
    async (type: string) => {
      setDismissedPopups((prev) => (prev.includes(type) ? prev : [...prev, type]));
      if (loggedIn) {
        await ApiClient.post('dismiss_popup', { popup_type: type });
      }
    },
    [loggedIn]
  );

  const refreshUserData = useCallback(async () => {
    if (!ApiClient.getToken()) return;
    const res = await ApiClient.post('get_user_data');
    if (res.success) {
      applyUserData(res);
    } else if (res.statusCode === 401 || res.banned || res.login_required) {
      ApiClient.setToken(null);
      setLoggedOut();
    }
  }, [applyUserData, setLoggedOut]);

  const loadTipsters = useCallback(async () => {
    const res = await ApiClient.get('get_tipsters');
    if (res.success && Array.isArray(res.tipsters)) {
      setTipsters(res.tipsters);
    }
  }, []);

  const loadSingleSlips = useCallback(async () => {
    const res = await ApiClient.get('get_single_slips');
    if (res.success && Array.isArray(res.slips)) {
      setSingleSlips(res.slips);
    }
    if (loggedIn) {
      const my = await ApiClient.post('get_my_single_slips');
      if (my.success && Array.isArray(my.slips)) {
        setPurchasedSingleSlips(my.slips);
      }
    }
  }, [loggedIn]);

  const toggleFollowTipster = useCallback(
    async (tipsterId: number, current: boolean) => {
      if (!loggedIn) {
        setIsLoginModalOpen(true);
        return { success: false, message: 'Ingia kwanza kufuata tipster' };
      }
      const action = current ? 'unfollow_tipster' : 'follow_tipster';
      const res = await ApiClient.post(action, { tipster_id: tipsterId });
      if (res.success) {
        setTipsters((prev) =>
          prev.map((t) =>
            t.id === tipsterId
              ? {
                  ...t,
                  is_following: !current,
                  followers_count: Math.max(0, (t.followers_count || 0) + (current ? -1 : 1)),
                }
              : t
          )
        );
        return { success: true, message: res.message || 'Umefanikiwa!' };
      }
      return { success: false, message: res.error || 'Hitilafu' };
    },
    [loggedIn]
  );

  const logout = useCallback(async () => {
    await ApiClient.post('logout');
    ApiClient.setToken(null);
    setLoggedOut();
    showSnack('Umetoka kwenye akaunti');
  }, [setLoggedOut, showSnack]);

  // Periodic health check and win check (just like Flutter Timer.periodic)
  useEffect(() => {
    if (!loggedIn) return;

    const sessionInterval = setInterval(async () => {
      const res = await ApiClient.post('check_session');
      if (!res.success && (res.banned || res.session_status === 'kicked')) {
        setIsSessionBanned(!!res.banned);
        setSessionInvalidReason(
          res.ban_reason ||
            (res.session_status === 'kicked'
              ? 'Umeingiwa kwenye kifaa kingine. Tafadhali ingia tena.'
              : res.error || 'Session imekwisha.')
        );
      }
    }, 30000);

    const winInterval = setInterval(async () => {
      if (isPopupDismissed('win_popup')) return;
      const res = await ApiClient.post('check_new_win');
      if (res.success && res.show_popup && res.betslip) {
        setActiveWinSlip(res.betslip);
      }
    }, 20000);

    // Immediate warning check once after login
    if (!isPopupDismissed('warning_popup')) {
      ApiClient.post('check_immediate_warning').then((res) => {
        if (res.success && res.show_warning && res.message) {
          setActiveWarning({
            message: res.message,
            severity: res.severity || 'medium',
          });
        }
      });
    }

    return () => {
      clearInterval(sessionInterval);
      clearInterval(winInterval);
    };
  }, [loggedIn, isPopupDismissed]);

  // Initial load
  useEffect(() => {
    loadTipsters();
    loadSingleSlips();
    const token = ApiClient.getToken();
    if (token) {
      refreshUserData();
    }
  }, [loadTipsters, loadSingleSlips, refreshUserData]);

  return (
    <AppContext.Provider
      value={{
        loggedIn,
        isTipster,
        isSubscribed,
        user,
        subscription,
        payments,
        todaysSlips,
        allSlips,
        bettingCompanies,
        tipsters,
        followedTipsters,
        singleSlips,
        purchasedSingleSlips,
        dismissedPopups,
        displayPhone,
        activeWarning,
        activeWinSlip,
        sessionInvalidReason,
        isSessionBanned,

        applyUserData,
        setLoggedOut,
        isPopupDismissed,
        dismissPopup,
        refreshUserData,
        loadTipsters,
        loadSingleSlips,
        toggleFollowTipster,
        logout,

        openLoginModal: () => setIsLoginModalOpen(true),
        closeLoginModal: () => setIsLoginModalOpen(false),
        isLoginModalOpen,

        openPackagesModal: (pkg) => {
          setSelectedPackageForPayment(pkg || null);
          setIsPackagesModalOpen(true);
        },
        closePackagesModal: () => {
          setIsPackagesModalOpen(false);
          setSelectedPackageForPayment(null);
        },
        isPackagesModalOpen,
        selectedPackageForPayment,

        openSingleSlipModal: (slip) => setSelectedSlipForPayment(slip),
        closeSingleSlipModal: () => setSelectedSlipForPayment(null),
        selectedSlipForPayment,

        showWinPopupManually: (slip) =>
          setActiveWinSlip(
            slip || {
              id: 99999,
              booking_code: 'WIN7788',
              odds: '18.45',
              company_name: 'BETPAWA',
              created_date: new Date().toISOString().split('T')[0],
              match_details: 'Arsenal Win • Real Madrid Over 2.5 • PSG Win',
              result_status: 'won',
            }
          ),
        closeWinPopup: () => setActiveWinSlip(null),

        showWarningPopupManually: (msg, sev = 'medium') =>
          setActiveWarning({
            message:
              msg ||
              'Tahadhari: Hakikisha umethibitisha namba yako ya simu kwa usahihi ili kutopoteza rekodi ya malipo.',
            severity: sev,
          }),
        closeWarningPopup: () => setActiveWarning(null),

        snack,
        showSnack,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error('useApp must be used within AppProvider');
  return context;
};
