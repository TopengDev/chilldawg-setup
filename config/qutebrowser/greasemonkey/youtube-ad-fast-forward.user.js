// ==UserScript==
// @name           YouTube Adblock Bypass
// @namespace      http://tampermonkey.net/
// @version        1.3
// @description    Bypasses YouTube's adblock detection by hiding notice and forcing playback
// @author         sisyphus
// @match          *://*.youtube.com/*
// @grant          none
// @run-at         document-start
// ==UserScript==

(function() {
    'use strict';

    const observer = new MutationObserver(() => {
        const overlay = document.querySelector('tp-yt-iron-overlay-backdrop');
        const dialog = document.querySelector('ytd-enforcement-message-view-model');
        const promo = document.querySelector('#fulfillment-player-error-message');

        if (overlay) overlay.remove();
        if (dialog) dialog.remove();
        if (promo) promo.remove();

        const video = document.querySelector('video');
        if (video && video.paused && !video.ended) {
            const ad = document.querySelector('.ad-showing, .ad-interrupting');
            if (ad) {
                video.playbackRate = 16;
                video.muted = true;
                video.currentTime = video.duration - 0.1;

                const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button');
                if (skipBtn) skipBtn.click();
            } else {
                video.play().catch(() => {});
            }
        }
    });

    observer.observe(document.documentElement, { childList: true, subtree: true });

    setInterval(() => {
        const video = document.querySelector('video');
        const ad = document.querySelector('.ad-showing, .ad-interrupting');

        if (ad && video && !isNaN(video.duration)) {
            video.playbackRate = 16;
            video.muted = true;
            video.currentTime = video.duration - 0.1;
        }

        const skipSelectors = [
            '.ytp-ad-skip-button',
            '.ytp-ad-skip-button-modern',
            '.ytp-skip-ad-button',
            '.ytp-ad-skip-button-container',
            '.ytp-ad-skip-button-slot',
            '[class*="ytp-ad-skip"]'
        ];

        skipSelectors.forEach(selector => {
            const btns = document.querySelectorAll(selector);
            btns.forEach(btn => { if (btn) btn.click(); });
        });

        const allButtons = document.querySelectorAll('button, div, span');
        allButtons.forEach(el => {
            if (el.innerText && /Skip|Lewati|Iklan/i.test(el.innerText) && el.innerText.length < 20) {
                if (el.offsetWidth > 0 || el.offsetHeight > 0) {
                    el.click();
                }
            }
        });
    }, 200);
})();
