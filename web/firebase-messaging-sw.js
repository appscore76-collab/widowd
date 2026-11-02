// Firebase Cloud Messaging service worker for the web app.
// Handles notifications that arrive while the site is in the background.
// The firebaseConfig below is the widowd-dev web app's public client config.
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBpMHPEWhNJ1CwD2KhB6K_XGdutyJRcmxs',
  authDomain: 'widowd-dev.firebaseapp.com',
  projectId: 'widowd-dev',
  storageBucket: 'widowd-dev.firebasestorage.app',
  messagingSenderId: '747251750497',
  appId: '1:747251750497:web:7f126fda53735e8d133c20',
  measurementId: 'G-VFE5G7SQ3J',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  const notification = message.notification || {};
  self.registration.showNotification(notification.title || 'widowd', {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: message.data || {},
  });
});
