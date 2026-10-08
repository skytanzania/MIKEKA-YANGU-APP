export interface User {
  id: number;
  phone_number: string;
  name?: string;
  dismissed_popups?: string | string[];
  created_at?: string;
  role?: string;
}

export interface Subscription {
  id?: number;
  package_type: 'normal' | 'tanzanite' | 'vip' | 'vvip' | string;
  start_date?: string;
  end_date: string;
  is_active?: boolean | number;
}

export interface Payment {
  id: number;
  order_id?: string;
  amount: number | string;
  package_type: string;
  payment_status: 'completed' | 'pending' | 'failed' | string;
  phone_number?: string;
  created_at: string;
}

export interface Tipster {
  id: number;
  name?: string;
  phone_number?: string;
  tipster_name?: string;
  tipster_bio?: string;
  tipster_avatar?: string;
  tipster_rating?: string | number;
  tipster_success_rate?: string | number;
  tipster_total_tips?: number;
  tipster_won_tips?: number;
  tipster_verified?: boolean | number;
  tipster_badge?: string | null;
  followers_count?: number;
  tips_count?: number;
  active_tips_count?: number;
  single_slips_count?: number;
  is_following?: boolean;
  slips?: Betslip[];
  system_betslip?: Betslip;
  single_slips?: SingleSlip[];
}

export interface Betslip {
  id: number;
  booking_code: string;
  odds: string | number;
  company_name?: string;
  company_code?: string;
  logo_url?: string;
  match_details?: string;
  package_type?: string;
  result_status?: 'won' | 'lost' | 'pending' | string;
  validity_time?: string;
  created_date?: string;
  slip_type?: string;
  price?: number | string;
  likes_count?: number;
  views_count?: number;
}

export interface SingleSlip extends Betslip {
  tipster_id?: number;
  tipster_name?: string;
  tipster_user_name?: string;
  tipster_avatar?: string;
  is_purchased?: boolean;
}

export interface ApiResponse<T = any> {
  success: boolean;
  error?: string;
  statusCode?: number;
  banned?: boolean;
  ban_reason?: string;
  session_status?: 'active' | 'banned' | 'kicked';
  login_required?: boolean;
  action?: string;
  session_token?: string;
  message?: string;
  show_popup?: boolean;
  show_warning?: boolean;
  severity?: 'low' | 'medium' | 'high' | 'critical';
  order_id?: string | number;
  is_payment_successful?: boolean;
  betslip?: Betslip;
  tipster?: Tipster;
  tipsters?: Tipster[];
  slips?: any[];
  user?: User;
  subscription?: Subscription;
  payments?: Payment[];
  todays_slips?: Betslip[];
  all_slips?: Betslip[];
  betting_companies?: any[];
  followed_tipsters?: any[];
  purchased_single_slips?: SingleSlip[];
  is_tipster?: boolean;
  is_subscribed?: boolean;
  display_phone?: string;
  data?: T;
}

export interface PackageInfo {
  type: 'normal' | 'tanzanite' | 'vip' | 'vvip';
  name: string;
  price: number;
  duration: string;
  color: string;
  badge: string;
}

export const PACKAGES: Record<string, PackageInfo> = {
  normal: {
    type: 'normal',
    name: 'NORMAL',
    price: 3000,
    duration: 'Siku 1 (Masaa 24)',
    color: '#00B4FF',
    badge: '1 DAY',
  },
  tanzanite: {
    type: 'tanzanite',
    name: 'TANZANITE',
    price: 5000,
    duration: 'Siku 3 (Masaa 72)',
    color: '#7B5CFF',
    badge: '3 DAYS',
  },
  vip: {
    type: 'vip',
    name: 'VIP',
    price: 10000,
    duration: 'Siku 7 (Wiki 1)',
    color: '#FFD700',
    badge: '1 WEEK',
  },
  vvip: {
    type: 'vvip',
    name: 'VVIP',
    price: 30000,
    duration: 'Siku 30 (Mwezi 1)',
    color: '#FF0055',
    badge: '1 MONTH',
  },
};
