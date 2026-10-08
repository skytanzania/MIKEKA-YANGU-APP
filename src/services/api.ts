import { ApiResponse } from '../types/mikeka';

const API_BASE = 'https://mikekaapp.co.tz/api';
const TOKEN_KEY = 'mikeka_session_token';
const DEVICE_KEY = 'mikeka_device_id';

class ApiClientService {
  private cachedToken: string | null = null;
  private deviceId: string | null = null;

  constructor() {
    if (typeof window !== 'undefined') {
      this.cachedToken = localStorage.getItem(TOKEN_KEY);
      let dev = localStorage.getItem(DEVICE_KEY);
      if (!dev) {
        dev = 'web_' + Math.random().toString(36).substring(2, 12) + '_' + Date.now();
        localStorage.setItem(DEVICE_KEY, dev);
      }
      this.deviceId = dev;
    }
  }

  getToken(): string | null {
    if (!this.cachedToken && typeof window !== 'undefined') {
      this.cachedToken = localStorage.getItem(TOKEN_KEY);
    }
    return this.cachedToken;
  }

  setToken(token: string | null) {
    this.cachedToken = token;
    if (typeof window !== 'undefined') {
      if (token === null) {
        localStorage.removeItem(TOKEN_KEY);
      } else {
        localStorage.setItem(TOKEN_KEY, token);
      }
    }
  }

  getDeviceId(): string {
    if (!this.deviceId && typeof window !== 'undefined') {
      let dev = localStorage.getItem(DEVICE_KEY);
      if (!dev) {
        dev = 'web_' + Math.random().toString(36).substring(2, 12) + '_' + Date.now();
        localStorage.setItem(DEVICE_KEY, dev);
      }
      this.deviceId = dev;
    }
    return this.deviceId || 'web_client_1';
  }

  private getHeaders(token: string | null): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };
    if (token && token.trim().length > 0) {
      headers['X-Session-Token'] = token;
    }
    if (this.deviceId) {
      headers['X-Device-Hash'] = this.deviceId;
    }
    return headers;
  }

  async post<T = any>(
    action: string,
    data?: Record<string, any>,
    requiresAuth = true
  ): Promise<ApiResponse<T>> {
    try {
      const token = requiresAuth ? this.getToken() : null;
      const params = new URLSearchParams();
      params.append('action', action);

      if (data) {
        Object.entries(data).forEach(([k, v]) => {
          if (v !== undefined && v !== null) {
            params.append(k, String(v));
          }
        });
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 25000);

      const response = await fetch(API_BASE, {
        method: 'POST',
        headers: this.getHeaders(token),
        body: params.toString(),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      const json = await response.json();
      return {
        ...json,
        statusCode: response.status,
      };
    } catch (err: any) {
      console.warn(`[ApiClient] POST ${action} failed:`, err);
      return {
        success: false,
        error: 'Hitilafu ya mtandao. Angalia internet.',
        statusCode: 0,
      };
    }
  }

  async get<T = any>(
    action: string,
    data?: Record<string, any>,
    requiresAuth = false
  ): Promise<ApiResponse<T>> {
    try {
      const token = requiresAuth ? this.getToken() : null;
      const url = new URL(API_BASE);
      url.searchParams.append('action', action);

      if (data) {
        Object.entries(data).forEach(([k, v]) => {
          if (v !== undefined && v !== null) {
            url.searchParams.append(k, String(v));
          }
        });
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 25000);

      const response = await fetch(url.toString(), {
        method: 'GET',
        headers: this.getHeaders(token),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);
      const json = await response.json();
      return {
        ...json,
        statusCode: response.status,
      };
    } catch (err: any) {
      console.warn(`[ApiClient] GET ${action} failed:`, err);
      return {
        success: false,
        error: 'Hitilafu ya mtandao. Angalia internet.',
        statusCode: 0,
      };
    }
  }
}

export const ApiClient = new ApiClientService();
