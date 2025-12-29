# 🚀 Quick Start Guide - Self-Hosted Weather Proxy

## Super Simple 3-Step Setup

### Step 1: Upload Script to Your Server

**Option A: Copy script directly**
1. Copy the contents of `setup-proxy.sh` file
2. SSH into your server: `ssh username@your-server-ip`
3. Create the file: `nano setup-proxy.sh`
4. Paste the contents, save (Ctrl+X, Y, Enter)
5. Make it executable: `chmod +x setup-proxy.sh`

**Option B: Upload via SCP**
```bash
# From your local computer
scp setup-proxy.sh username@your-server-ip:~/
```

---

### Step 2: Run the Setup Script

**On your server:**
```bash
cd ~
chmod +x setup-proxy.sh
./setup-proxy.sh
```

**That's it!** The script will:
- ✅ Install Node.js (if needed)
- ✅ Create project files
- ✅ Install dependencies
- ✅ Start the server
- ✅ Show you your server URL

---

### Step 3: Configure Flutter

**Get your server IP from the script output, then:**

```bash
flutter run --dart-define=WEATHER_PROXY_URL=http://YOUR-SERVER-IP:3000
```

**Replace `YOUR-SERVER-IP` with the IP shown by the script.**

---

## ✅ Test It Works

**On your server, test the health endpoint:**
```bash
curl http://localhost:3000/health
```

**Should return:** `{"status":"ok","timestamp":"..."}`

**From your local computer, test:**
```bash
curl http://YOUR-SERVER-IP:3000/health
```

**If both work, you're done! 🎉**

---

## 🔧 If Something Goes Wrong

**Check server logs:**
```bash
pm2 logs weather-proxy
```

**Restart server:**
```bash
pm2 restart weather-proxy
```

**Check server status:**
```bash
pm2 status
```

---

## 📖 Need More Details?

See `SELF_HOSTED_SETUP.md` for detailed step-by-step instructions.

---

## 🎯 What You'll See

After running the script, you'll see something like:

```
✅ Setup Complete!
==================

📍 Server IP: 192.168.1.100
🌐 Proxy URL: http://192.168.1.100:3000

📝 Next steps:
1. Configure firewall: sudo ufw allow 3000/tcp
2. Test health endpoint: curl http://192.168.1.100:3000/health
3. In Flutter, run: flutter run --dart-define=WEATHER_PROXY_URL=http://192.168.1.100:3000
```

**Just copy that URL and use it in Flutter!**

