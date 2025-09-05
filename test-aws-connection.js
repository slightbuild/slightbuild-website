#!/usr/bin/env node

/**
 * Test AWS Connection and Account Information
 * This script verifies AWS credentials are working and shows account details
 */

const AWS = require('aws-sdk');

// Set up AWS configuration
AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  sessionToken: process.env.AWS_SESSION_TOKEN,
  region: 'us-east-1'
});

console.log('🔍 Testing AWS Connection...\n');

// Test connection with STS
const sts = new AWS.STS();
sts.getCallerIdentity({}, (err, data) => {
  if (err) {
    console.error('❌ AWS Connection Failed:', err.message);
    process.exit(1);
  }
  
  console.log('✅ AWS Connection Successful!');
  console.log(`Account ID: ${data.Account}`);
  console.log(`User ARN: ${data.Arn}`);
  console.log(`User ID: ${data.UserId}`);
  console.log('');
  
  // Test Amplify service access
  const amplify = new AWS.Amplify();
  amplify.listApps({}, (err, apps) => {
    if (err) {
      console.log('⚠️  Amplify Access:', err.message);
      console.log('Note: This is expected if no Amplify apps exist yet.\n');
    } else {
      console.log('✅ Amplify Service Access: OK');
      console.log(`Found ${apps.apps.length} existing Amplify apps\n`);
    }
    
    console.log('🚀 Ready to proceed with deployment!');
    console.log('\nNext steps:');
    console.log('1. Go to AWS Amplify Console: https://console.aws.amazon.com/amplify/');
    console.log('2. Create new app and connect GitHub repository');
    console.log('3. Use the amplify.yml file from this project');
  });
});