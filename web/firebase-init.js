// Firebase initialization for web
(function () {
    const firebaseConfig = {
        apiKey: "AIzaSyBUduwQCS_4HXaEmn_Ilf57BxDA9DT865g",
        authDomain: "projectshowcase-b2748.firebaseapp.com",
        projectId: "projectshowcase-b2748",
        storageBucket: "projectshowcase-b2748.firebasestorage.app",
        messagingSenderId: "279672202046",
        appId: "1:279672202046:web:b409f9affe2a8bd4fd826f"
    };

    // Initialize Firebase
    if (typeof firebase !== 'undefined') {
        try {
            if (!firebase.apps.length) {
                firebase.initializeApp(firebaseConfig);
                console.log('Firebase initialized successfully');
            } else {
                console.log('Firebase already initialized');
            }
        } catch (error) {
            console.error('Firebase initialization error:', error);
        }
    } else {
        console.error('Firebase SDK not loaded');
    }
})();
