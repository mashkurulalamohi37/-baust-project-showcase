// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

// Your web app's Firebase configuration
const firebaseConfig = {
  apiKey: "AIzaSyBJjP-avXJ0btdDrS-hZr5mUQmm2Ieet-g",
  authDomain: "projectshowcase-56c2b.firebaseapp.com",
  projectId: "projectshowcase-56c2b",
  storageBucket: "projectshowcase-56c2b.firebasestorage.app",
  messagingSenderId: "170226610519",
  appId: "1:170226610519:web:your-web-app-id"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
