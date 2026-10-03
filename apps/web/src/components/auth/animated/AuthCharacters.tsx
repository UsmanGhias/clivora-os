"use client";

import { useEffect, useRef } from "react";
import { useAuthAnimRegister, type AuthAnimApi } from "./AuthAnimContext";

function clamp(v: number, lo: number, hi: number) {
  return Math.max(lo, Math.min(hi, v));
}

export function AuthCharacters() {
  const register = useAuthAnimRegister();

  const charPurple = useRef<HTMLDivElement>(null);
  const charBlack = useRef<HTMLDivElement>(null);
  const charOrange = useRef<HTMLDivElement>(null);
  const charYellow = useRef<HTMLDivElement>(null);
  const eyesPurple = useRef<HTMLDivElement>(null);
  const eyesBlack = useRef<HTMLDivElement>(null);
  const dotsOrange = useRef<HTMLDivElement>(null);
  const dotsYellow = useRef<HTMLDivElement>(null);
  const yellowMouth = useRef<HTMLDivElement>(null);
  const purpleEye1 = useRef<HTMLDivElement>(null);
  const purpleEye2 = useRef<HTMLDivElement>(null);
  const blackEye1 = useRef<HTMLDivElement>(null);
  const blackEye2 = useRef<HTMLDivElement>(null);
  const orangeDot1 = useRef<HTMLDivElement>(null);
  const orangeDot2 = useRef<HTMLDivElement>(null);
  const yellowDot1 = useRef<HTMLDivElement>(null);
  const yellowDot2 = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const state = {
      mouseX: typeof window !== "undefined" ? window.innerWidth / 2 : 0,
      mouseY: typeof window !== "undefined" ? window.innerHeight / 2 : 0,
      isTyping: false,
      showPassword: false,
      passwordLen: 0,
      isLookingAtEachOther: false,
      isPurplePeeking: false,
      isErroring: false,
    };

    let pendingFrame = false;
    let lookTimer: ReturnType<typeof setTimeout> | null = null;
    let peekChainRunning = false;
    let errorBodyTimer: ReturnType<typeof setTimeout> | null = null;
    let errorMoodTimer: ReturnType<typeof setTimeout> | null = null;
    const blinkTimers: ReturnType<typeof setTimeout>[] = [];

    const setPupilTransform = (
      pupilEl: HTMLElement | null | undefined,
      force: { x: number; y: number } | null,
      maxDist: number,
    ) => {
      if (!pupilEl) return;
      if (force) {
        pupilEl.style.transform = `translate(${force.x}px, ${force.y}px)`;
        return;
      }
      const r = pupilEl.getBoundingClientRect();
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const dx = state.mouseX - cx;
      const dy = state.mouseY - cy;
      const dist = Math.min(Math.hypot(dx, dy), maxDist);
      const angle = Math.atan2(dy, dx);
      pupilEl.style.transform = `translate(${Math.cos(angle) * dist}px, ${Math.sin(angle) * dist}px)`;
    };

    const calculateBodyPosition = (charEl: HTMLElement) => {
      const rect = charEl.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 3;
      const dx = state.mouseX - cx;
      const dy = state.mouseY - cy;
      return {
        faceX: clamp(dx / 20, -15, 15),
        faceY: clamp(dy / 30, -10, 10),
        bodySkew: clamp(-dx / 120, -6, 6),
      };
    };

    const render = () => {
      pendingFrame = false;
      if (state.isErroring) return;

      const purple = charPurple.current;
      const black = charBlack.current;
      const orange = charOrange.current;
      const yellow = charYellow.current;
      if (!purple || !black || !orange || !yellow) return;

      const { isTyping, showPassword, passwordLen, isLookingAtEachOther, isPurplePeeking } = state;
      const pwHidden = passwordLen > 0 && !showPassword;
      const pwShown = passwordLen > 0 && showPassword;

      const purplePos = calculateBodyPosition(purple);
      const blackPos = calculateBodyPosition(black);
      const orangePos = calculateBodyPosition(orange);
      const yellowPos = calculateBodyPosition(yellow);

      purple.style.height = isTyping || pwHidden ? "440px" : "400px";
      if (pwShown) purple.style.transform = "skewX(0deg)";
      else if (isTyping || pwHidden) {
        purple.style.transform = `skewX(${purplePos.bodySkew - 12}deg) translateX(40px)`;
      } else purple.style.transform = `skewX(${purplePos.bodySkew}deg)`;

      if (eyesPurple.current) {
        if (pwShown) {
          eyesPurple.current.style.left = "20px";
          eyesPurple.current.style.top = "35px";
        } else if (isLookingAtEachOther) {
          eyesPurple.current.style.left = "55px";
          eyesPurple.current.style.top = "65px";
        } else {
          eyesPurple.current.style.left = `${45 + purplePos.faceX}px`;
          eyesPurple.current.style.top = `${40 + purplePos.faceY}px`;
        }
      }

      const purpleForce = pwShown
        ? { x: isPurplePeeking ? 4 : -4, y: isPurplePeeking ? 5 : -4 }
        : isLookingAtEachOther
          ? { x: 3, y: 4 }
          : null;
      setPupilTransform(purpleEye1.current?.querySelector(".aa-pupil") as HTMLElement, purpleForce, 5);
      setPupilTransform(purpleEye2.current?.querySelector(".aa-pupil") as HTMLElement, purpleForce, 5);

      if (pwShown) black.style.transform = "skewX(0deg)";
      else if (isLookingAtEachOther) {
        black.style.transform = `skewX(${blackPos.bodySkew * 1.5 + 10}deg) translateX(20px)`;
      } else if (isTyping || pwHidden) {
        black.style.transform = `skewX(${blackPos.bodySkew * 1.5}deg)`;
      } else black.style.transform = `skewX(${blackPos.bodySkew}deg)`;

      if (eyesBlack.current) {
        if (pwShown) {
          eyesBlack.current.style.left = "10px";
          eyesBlack.current.style.top = "28px";
        } else if (isLookingAtEachOther) {
          eyesBlack.current.style.left = "32px";
          eyesBlack.current.style.top = "12px";
        } else {
          eyesBlack.current.style.left = `${26 + blackPos.faceX}px`;
          eyesBlack.current.style.top = `${32 + blackPos.faceY}px`;
        }
      }

      const blackForce = pwShown
        ? { x: -4, y: -4 }
        : isLookingAtEachOther
          ? { x: 0, y: -4 }
          : null;
      setPupilTransform(blackEye1.current?.querySelector(".aa-pupil") as HTMLElement, blackForce, 4);
      setPupilTransform(blackEye2.current?.querySelector(".aa-pupil") as HTMLElement, blackForce, 4);

      orange.style.transform = pwShown ? "skewX(0deg)" : `skewX(${orangePos.bodySkew}deg)`;
      if (dotsOrange.current) {
        if (pwShown) {
          dotsOrange.current.style.left = "50px";
          dotsOrange.current.style.top = "85px";
        } else {
          dotsOrange.current.style.left = `${82 + orangePos.faceX}px`;
          dotsOrange.current.style.top = `${90 + orangePos.faceY}px`;
        }
      }
      const orangeForce = pwShown ? { x: -5, y: -4 } : null;
      setPupilTransform(orangeDot1.current, orangeForce, 5);
      setPupilTransform(orangeDot2.current, orangeForce, 5);

      yellow.style.transform = pwShown ? "skewX(0deg)" : `skewX(${yellowPos.bodySkew}deg)`;
      if (dotsYellow.current && yellowMouth.current) {
        if (pwShown) {
          dotsYellow.current.style.left = "20px";
          dotsYellow.current.style.top = "35px";
          yellowMouth.current.style.left = "10px";
          yellowMouth.current.style.top = "88px";
        } else {
          dotsYellow.current.style.left = `${52 + yellowPos.faceX}px`;
          dotsYellow.current.style.top = `${40 + yellowPos.faceY}px`;
          yellowMouth.current.style.left = `${40 + yellowPos.faceX}px`;
          yellowMouth.current.style.top = `${88 + yellowPos.faceY}px`;
        }
      }
      const yellowForce = pwShown ? { x: -5, y: -4 } : null;
      setPupilTransform(yellowDot1.current, yellowForce, 5);
      setPupilTransform(yellowDot2.current, yellowForce, 5);
    };

    const requestRender = () => {
      if (pendingFrame) return;
      pendingFrame = true;
      requestAnimationFrame(render);
    };

    const onMouseMove = (e: MouseEvent) => {
      state.mouseX = e.clientX;
      state.mouseY = e.clientY;
      requestRender();
    };

    const scheduleBlink = (charEl: HTMLElement | null) => {
      if (!charEl) return;
      const next = () => {
        const delay = 3000 + Math.random() * 4000;
        const t = setTimeout(() => {
          charEl.classList.add("blink");
          const t2 = setTimeout(() => {
            charEl.classList.remove("blink");
            next();
          }, 150);
          blinkTimers.push(t2);
        }, delay);
        blinkTimers.push(t);
      };
      next();
    };

    const startPeekChain = () => {
      if (peekChainRunning) return;
      peekChainRunning = true;
      const tick = () => {
        if (!(state.passwordLen > 0 && state.showPassword)) {
          peekChainRunning = false;
          state.isPurplePeeking = false;
          requestRender();
          return;
        }
        const t = setTimeout(() => {
          if (!(state.passwordLen > 0 && state.showPassword)) {
            peekChainRunning = false;
            state.isPurplePeeking = false;
            requestRender();
            return;
          }
          state.isPurplePeeking = true;
          requestRender();
          const t2 = setTimeout(() => {
            state.isPurplePeeking = false;
            requestRender();
            tick();
          }, 800);
          blinkTimers.push(t2);
        }, 2000 + Math.random() * 3000);
        blinkTimers.push(t);
      };
      tick();
    };

    const clearErrorClasses = () => {
      charPurple.current?.classList.remove("error-anim");
      charOrange.current?.classList.remove("crying");
      charYellow.current?.classList.remove("crying");
      yellowMouth.current?.classList.remove("sad");
      purpleEye1.current?.classList.remove("sad-eye");
      purpleEye2.current?.classList.remove("sad-eye");
      blackEye1.current?.classList.remove("sad-eye");
      blackEye2.current?.classList.remove("sad-eye");
    };

    const triggerError = () => {
      if (errorBodyTimer) clearTimeout(errorBodyTimer);
      if (errorMoodTimer) clearTimeout(errorMoodTimer);
      clearErrorClasses();
      state.isErroring = true;
      if (charPurple.current) {
        charPurple.current.style.transform = "";
        void charPurple.current.offsetWidth;
        charPurple.current.classList.add("error-anim");
      }
      yellowMouth.current?.classList.add("sad");
      purpleEye1.current?.classList.add("sad-eye");
      purpleEye2.current?.classList.add("sad-eye");
      blackEye1.current?.classList.add("sad-eye");
      blackEye2.current?.classList.add("sad-eye");
      charOrange.current?.classList.add("crying");
      charYellow.current?.classList.add("crying");

      errorBodyTimer = setTimeout(() => {
        charPurple.current?.classList.remove("error-anim");
        charOrange.current?.classList.remove("crying");
        charYellow.current?.classList.remove("crying");
        state.isErroring = false;
        requestRender();
        errorBodyTimer = null;
      }, 1300);

      errorMoodTimer = setTimeout(() => {
        yellowMouth.current?.classList.remove("sad");
        purpleEye1.current?.classList.remove("sad-eye");
        purpleEye2.current?.classList.remove("sad-eye");
        blackEye1.current?.classList.remove("sad-eye");
        blackEye2.current?.classList.remove("sad-eye");
        errorMoodTimer = null;
      }, 2200);
    };

    const api: AuthAnimApi = {
      setTyping: (v) => {
        state.isTyping = v;
        if (v) {
          state.isLookingAtEachOther = true;
          if (lookTimer) clearTimeout(lookTimer);
          lookTimer = setTimeout(() => {
            state.isLookingAtEachOther = false;
            lookTimer = null;
            requestRender();
          }, 800);
        } else {
          state.isLookingAtEachOther = false;
          if (lookTimer) {
            clearTimeout(lookTimer);
            lookTimer = null;
          }
        }
        requestRender();
      },
      setPasswordLen: (n) => {
        const wasZero = state.passwordLen === 0;
        state.passwordLen = n;
        if (wasZero && n > 0 && state.showPassword) startPeekChain();
        requestRender();
      },
      setShowPassword: (v) => {
        state.showPassword = v;
        if (state.passwordLen > 0 && v) startPeekChain();
        requestRender();
      },
      triggerError,
    };

    register?.(api);
    window.addEventListener("mousemove", onMouseMove, { passive: true });
    window.addEventListener("resize", requestRender);
    scheduleBlink(charPurple.current);
    scheduleBlink(charBlack.current);
    requestRender();

    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("resize", requestRender);
      if (lookTimer) clearTimeout(lookTimer);
      if (errorBodyTimer) clearTimeout(errorBodyTimer);
      if (errorMoodTimer) clearTimeout(errorMoodTimer);
      blinkTimers.forEach(clearTimeout);
    };
  }, [register]);

  return (
    <div className="aa-characters" aria-hidden="true">
      <div className="aa-char aa-char-purple" ref={charPurple}>
        <div className="aa-eyes" ref={eyesPurple}>
          <div className="aa-eye" ref={purpleEye1}>
            <div className="aa-pupil" />
          </div>
          <div className="aa-eye" ref={purpleEye2}>
            <div className="aa-pupil" />
          </div>
        </div>
      </div>
      <div className="aa-char aa-char-black" ref={charBlack}>
        <div className="aa-eyes" ref={eyesBlack}>
          <div className="aa-eye" ref={blackEye1}>
            <div className="aa-pupil" />
          </div>
          <div className="aa-eye" ref={blackEye2}>
            <div className="aa-pupil" />
          </div>
        </div>
      </div>
      <div className="aa-char aa-char-orange" ref={charOrange}>
        <div className="aa-dots" ref={dotsOrange}>
          <div className="aa-dot" ref={orangeDot1} />
          <div className="aa-dot" ref={orangeDot2} />
        </div>
      </div>
      <div className="aa-char aa-char-yellow" ref={charYellow}>
        <div className="aa-dots" ref={dotsYellow}>
          <div className="aa-dot" ref={yellowDot1} />
          <div className="aa-dot" ref={yellowDot2} />
        </div>
        <div className="aa-mouth" ref={yellowMouth} />
      </div>
    </div>
  );
}
