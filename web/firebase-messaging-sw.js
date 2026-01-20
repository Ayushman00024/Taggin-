// firebase-messaging-sw.js

// Import Firebase scripts (compat versions work best with PWAs)
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js");

// ✅ Taggin Firebase config
firebase.initializeApp({
  apiKey: "AIzaSyA0EDmjszfnmGR0m0ouIMn7vRhXRrxiKiA",
  authDomain: "tagginapp.firebaseapp.com",
  projectId: "tagginapp",
  storageBucket: "tagginapp.appspot.com",
  messagingSenderId: "771138066392",
  appId: "1:771138066392:web:e5d6a4c447f7519fe6c4ad",
  measurementId: "G-V0D1LK6PSB",
  vapidKey: "BBKe8Yf9op2PjsFDkfP6hJYYLcLb708EHPBrobhRsLhlELF5WagHt2n-XoakG9q9xZUmpKZIGjyCuNj9-kPC2M8"
});

// Retrieve Firebase Messaging instance
const messaging = firebase.messaging();

// 🔔 Handle background (service worker) messages
messaging.onBackgroundMessage((payload) => {
  console.log("📩 [Taggin SW] Background message received:", payload);

  const title = payload?.notification?.title || "Taggin";
  const body = payload?.notification?.body || "You’ve got a new message 💬";
  const icon = payload?.notification?.icon || "/icons/Icon-192.png";
  const clickUrl =
    payload?.data?.click_action ||
    payload?.fcmOptions?.link ||
    "https://tagginapp.web.app"; // fallback to your site root

  const options = {
    body,
    icon,
    badge: "/icons/Icon-192.png",
    data: { clickUrl },
    vibrate: [100, 50, 100],
    actions: [
      { action: "open", title: "Open Taggin" },
    ],
  };

  // Show notification
  self.registration.showNotification(title, options);
});

// 🧭 Handle click on notification
self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const targetUrl = event.notification.data?.clickUrl || "https://tagginapp.web.app";

  // Focus if a Taggin tab already open, else open new one
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes("tagginapp.web.app") && "focus" in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
