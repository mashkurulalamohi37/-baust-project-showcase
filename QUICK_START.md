# Quick Start - Connect to Supabase

## ✅ Your Credentials Are Already Configured!

Your `supabase_config.dart` already has credentials. Now follow these steps:

## Step 1: Run the Database Schema

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Select your project (or create one if needed)
3. Click **SQL Editor** in the left sidebar
4. Click **"New query"**
5. Open `supabase_schema.sql` from your project folder
6. **Copy ALL the SQL code** from that file
7. **Paste it** into the SQL Editor
8. Click **"Run"** button (or press Ctrl+Enter)

**Expected Result**: You should see "Success. No rows returned"

## Step 2: Create Storage Bucket

1. In Supabase dashboard, click **Storage** (left sidebar)
2. Click **"New bucket"**
3. Set:
   - **Name**: `project-files` (exactly this name)
   - **Public bucket**: ✅ **Check this box**
4. Click **"Create bucket"**

## Step 3: Verify Tables Were Created

1. Click **Table Editor** in the left sidebar
2. You should see these tables:
   - ✅ users
   - ✅ projects
   - ✅ reviews
   - ✅ bookmarks
   - ✅ feedback
   - ✅ notifications

## Step 4: Test Your App

1. In your terminal, run:
   ```bash
   flutter pub get
   flutter run
   ```

2. Check the console output - you should see:
   ```
   Supabase initialized successfully
   ```

3. Try to:
   - Sign up a new user
   - Create a project
   - Upload a file

## 🔍 Verify Connection

### Check in Supabase Dashboard:

1. **After signing up**: Go to Table Editor → `users` table → You should see your user
2. **After creating project**: Go to Table Editor → `projects` table → You should see your project
3. **After uploading file**: Go to Storage → `project-files` bucket → You should see uploaded files

## ❌ If Something Doesn't Work

### Check Console Logs:
- Look for error messages in your Flutter console
- Common errors:
  - "Bucket not found" → Create the `project-files` bucket
  - "Table does not exist" → Run the SQL schema again
  - "Permission denied" → Check RLS policies

### Verify Your Credentials:
- Open `lib/config/supabase_config.dart`
- Make sure `supabaseUrl` matches your project URL
- Make sure `supabaseAnonKey` is your anon key (from Settings → API)

## 📝 Need More Details?

See `SUPABASE_SETUP_GUIDE.md` for detailed step-by-step instructions.

