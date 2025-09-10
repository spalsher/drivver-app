# Setup Instructions for Drivrr App Development

## 1. Install Flutter

### For Linux:
```bash
# Download Flutter
cd ~/
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz

# Extract Flutter
tar xf flutter_linux_3.24.5-stable.tar.xz

# Add Flutter to PATH (add this to your ~/.bashrc or ~/.zshrc)
export PATH="$PATH:$HOME/flutter/bin"

# Reload your shell
source ~/.bashrc

# Verify installation
flutter doctor
```

### Alternative: Using Snap
```bash
sudo snap install flutter --classic
```

## 2. Install Dependencies

### Android Development:
```bash
# Install Android Studio or Android Command Line Tools
sudo apt update
sudo apt install android-sdk

# Or download Android Studio from: https://developer.android.com/studio
```

### iOS Development (if on macOS):
- Install Xcode from the App Store
- Install Xcode command line tools: `xcode-select --install`

## 3. Install Node.js and PostgreSQL

### Node.js:
```bash
# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version
npm --version
```

### PostgreSQL:
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database user
sudo -u postgres createuser --interactive
sudo -u postgres createdb drivrr_db
```

## 4. Get API Keys

### MapTiler:
1. Go to https://maptiler.com/
2. Sign up for a free account
3. Get your API key from the dashboard
4. Free tier includes 100,000 map requests per month

### Stripe (for payments):
1. Go to https://stripe.com/
2. Create an account
3. Get your publishable and secret keys from the dashboard
4. Use test keys for development

## 5. Environment Variables

Create a `.env` file in the project root:
```env
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/drivrr_db

# MapTiler
MAPTILER_API_KEY=your_maptiler_api_key_here

# Stripe
STRIPE_PUBLISHABLE_KEY=pk_test_your_key_here
STRIPE_SECRET_KEY=sk_test_your_key_here

# JWT
JWT_SECRET=your_super_secret_jwt_key_here

# Server
PORT=3000
NODE_ENV=development
```

## 6. Project Structure Creation

After Flutter is installed, run these commands to create the project structure:

```bash
# Create customer app
flutter create customer_app
cd customer_app

# Configure for Android and iOS
flutter config --enable-web --no-enable-macos-desktop --no-enable-windows-desktop --no-enable-linux-desktop

cd ..

# Create driver app
flutter create driver_app
cd driver_app

# Configure for Android and iOS
flutter config --enable-web --no-enable-macos-desktop --no-enable-windows-desktop --no-enable-linux-desktop

cd ..

# Create backend
mkdir backend
cd backend
npm init -y
npm install express cors helmet morgan dotenv bcryptjs jsonwebtoken socket.io pg
npm install -D nodemon concurrently

cd ..
```

## 7. Next Steps

1. Complete Flutter installation using the instructions above
2. Run `flutter doctor` to check for any issues
3. Install Android Studio or configure Android SDK
4. Set up the database and environment variables
5. Get your MapTiler API key
6. Run the project creation commands
7. Start development with Phase 1 from the PROJECT_PLAN.md

## Troubleshooting

### Flutter Issues:
- Run `flutter doctor` to diagnose problems
- Make sure Android SDK is properly configured
- Accept Android licenses: `flutter doctor --android-licenses`

### Database Issues:
- Check PostgreSQL service: `sudo systemctl status postgresql`
- Test connection: `sudo -u postgres psql`
- Create database: `CREATE DATABASE drivrr_db;`

### Node.js Issues:
- Update npm: `npm install -g npm@latest`
- Clear npm cache: `npm cache clean --force`
- Check permissions for global packages

## Support

If you encounter any issues during setup, refer to the official documentation:
- Flutter: https://docs.flutter.dev/get-started/install
- Node.js: https://nodejs.org/en/docs/
- PostgreSQL: https://www.postgresql.org/docs/
