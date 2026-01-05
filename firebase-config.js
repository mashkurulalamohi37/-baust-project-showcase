// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";
import { getAnalytics } from "firebase/analytics";

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyApRlzv4wFD2XzixVUCXxYrkHwD-tNL7hw",
  authDomain: "projectshowcase-b2748.firebaseapp.com",
  projectId: "projectshowcase-b2748",
  storageBucket: "projectshowcase-b2748.firebasestorage.app",
  messagingSenderId: "279672202046",
  appId: "1:279672202046:web:4abcdc83d436c829fd826f",
  measurementId: "G-ECS98B0LPE"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const analytics = getAnalytics(app);
