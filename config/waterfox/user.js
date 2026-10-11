// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 kaayzouee
// Author: https://github.com/kaayzouee

// Neodots Waterfox preferences.
// Managed preferences are reapplied on browser startup.

// ---------------------------------------------------------------------------
// Tracking protection and cookie partitioning
// ---------------------------------------------------------------------------

user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);

user_pref("network.cookie.cookieBehavior", 5);
user_pref("network.cookie.cookieBehavior.pbmode", 5);

// ---------------------------------------------------------------------------
// Fingerprinting resistance
// ---------------------------------------------------------------------------

// Intentional compatibility trade-off.
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.pbmode", true);
user_pref("privacy.resistFingerprinting.letterboxing", true);

// ---------------------------------------------------------------------------
// Network requests and prefetching
// ---------------------------------------------------------------------------

user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.urlbar.speculativeConnect.enabled", false);

// ---------------------------------------------------------------------------
// Website APIs
// ---------------------------------------------------------------------------

user_pref("geo.enabled", false);
user_pref("dom.battery.enabled", false);
user_pref("dom.event.clipboardevents.enabled", false);

// ---------------------------------------------------------------------------
// Tracking-related requests
// ---------------------------------------------------------------------------

user_pref("beacon.enabled", false);
user_pref("browser.send_pings", false);

// ---------------------------------------------------------------------------
// Search suggestions
// ---------------------------------------------------------------------------

user_pref("browser.search.suggest.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);

// ---------------------------------------------------------------------------
// Cookies, cache and autoplay
// ---------------------------------------------------------------------------

// Session-only cookie lifetime can log you out of websites.
user_pref("network.cookie.lifetimePolicy", 2);

user_pref("browser.cache.offline.enable", false);
user_pref("media.autoplay.default", 5);

// WebRTC is disabled: browser-based calls will not work normally.
user_pref("media.peerconnection.enabled", false);

// ---------------------------------------------------------------------------
// Neodots userChrome compatibility
// ---------------------------------------------------------------------------

// These preferences support the existing River userChrome.css customization.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.drawInTitlebar", true);
user_pref("widget.gtk.non-native-titlebar-buttons.enabled", true);
