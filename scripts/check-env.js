#!/usr/bin/env node

// Script to check if all required environment variables are set
// Run with: node scripts/check-env.js

const requiredEnvVars = [
  'NEXT_PUBLIC_SUPABASE_URL',
  'NEXT_PUBLIC_SUPABASE_ANON_KEY', 
  'SUPABASE_SERVICE_ROLE_KEY',
  'CREEM_API_KEY',
  'CREEM_API_URL',
  'CREEM_WEBHOOK_SECRET',
  'NEXT_PUBLIC_SITE_URL'
];

const optionalEnvVars = [
  'CREEM_SUCCESS_URL'
];

console.log('🔍 Checking environment variables...\n');

let hasErrors = false;

console.log('📋 Required variables:');
requiredEnvVars.forEach(varName => {
  const value = process.env[varName];
  if (!value) {
    console.log(`❌ ${varName}: NOT SET`);
    hasErrors = true;
  } else {
    // Show first few chars for security
    const displayValue = varName.includes('KEY') || varName.includes('SECRET') 
      ? `${value.substring(0, 8)}...` 
      : value;
    console.log(`✅ ${varName}: ${displayValue}`);
  }
});

console.log('\n📋 Optional variables:');
optionalEnvVars.forEach(varName => {
  const value = process.env[varName];
  if (!value) {
    console.log(`⚠️  ${varName}: NOT SET (optional)`);
  } else {
    console.log(`✅ ${varName}: ${value}`);
  }
});

console.log('\n🔧 Environment validation:');

// Check Supabase URL format
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
if (supabaseUrl && !supabaseUrl.startsWith('https://')) {
  console.log('❌ NEXT_PUBLIC_SUPABASE_URL should start with https://');
  hasErrors = true;
} else if (supabaseUrl) {
  console.log('✅ Supabase URL format is valid');
}

// Check Creem API URL format
const creemUrl = process.env.CREEM_API_URL;
if (creemUrl && !creemUrl.startsWith('https://')) {
  console.log('❌ CREEM_API_URL should start with https://');
  hasErrors = true;
} else if (creemUrl) {
  console.log('✅ Creem API URL format is valid');
}

// Check site URL format
const siteUrl = process.env.NEXT_PUBLIC_SITE_URL;
if (siteUrl && !siteUrl.startsWith('https://')) {
  console.log('⚠️  NEXT_PUBLIC_SITE_URL should start with https:// for production');
} else if (siteUrl) {
  console.log('✅ Site URL format is valid');
}

console.log('\n' + '='.repeat(50));

if (hasErrors) {
  console.log('❌ Environment check failed! Please set missing variables.');
  console.log('\n📝 For Vercel deployment:');
  console.log('1. Go to your Vercel dashboard');
  console.log('2. Select your project');
  console.log('3. Go to Settings > Environment Variables');
  console.log('4. Add all missing variables');
  console.log('5. Redeploy your application');
  process.exit(1);
} else {
  console.log('✅ All required environment variables are set!');
  process.exit(0);
}
