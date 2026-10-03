"use client";

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useRef,
  type ReactNode,
} from "react";

export type AuthAnimApi = {
  setTyping: (v: boolean) => void;
  setPasswordLen: (n: number) => void;
  setShowPassword: (v: boolean) => void;
  triggerError: () => void;
};

type AuthAnimInternal = AuthAnimApi & {
  register: (api: AuthAnimApi) => void;
};

const AuthAnimContext = createContext<AuthAnimInternal | null>(null);

export function AuthAnimProvider({ children }: { children: ReactNode }) {
  const apiRef = useRef<AuthAnimApi | null>(null);

  const register = useCallback((api: AuthAnimApi) => {
    apiRef.current = api;
  }, []);

  const value = useMemo<AuthAnimInternal>(
    () => ({
      register,
      setTyping: (v) => apiRef.current?.setTyping(v),
      setPasswordLen: (n) => apiRef.current?.setPasswordLen(n),
      setShowPassword: (v) => apiRef.current?.setShowPassword(v),
      triggerError: () => apiRef.current?.triggerError(),
    }),
    [register],
  );

  return <AuthAnimContext.Provider value={value}>{children}</AuthAnimContext.Provider>;
}

export function useAuthAnim() {
  const ctx = useContext(AuthAnimContext);
  if (!ctx) {
    return {
      setTyping: () => undefined,
      setPasswordLen: () => undefined,
      setShowPassword: () => undefined,
      triggerError: () => undefined,
    } satisfies AuthAnimApi;
  }
  return ctx;
}

export function useAuthAnimRegister() {
  const ctx = useContext(AuthAnimContext);
  return ctx?.register;
}
