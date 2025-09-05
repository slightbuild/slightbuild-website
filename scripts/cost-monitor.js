#!/usr/bin/env node

/**
 * SlightBuild AWS Cost Monitoring Script
 * 
 * This script monitors AWS costs, provides alerts, and generates reports
 * for the SlightBuild website deployment.
 * 
 * Usage:
 *   node cost-monitor.js --report
 *   node cost-monitor.js --alert
 *   node cost-monitor.js --optimize
 */

const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  region: process.env.AWS_REGION || 'us-east-1',
  appName: process.env.APP_NAME || 'slightbuild',
  budgetLimit: parseFloat(process.env.COST_BUDGET_LIMIT) || 10.0,
  alertThreshold: 0.8, // 80% of budget
  services: [
    'Amazon Amplify',
    'Amazon CloudFront', 
    'Amazon Route 53',
    'AWS Certificate Manager',
    'Amazon CloudWatch',
    'Amazon S3'
  ],
  outputDir: path.join(__dirname, '..', 'reports')
};

// AWS SDK Configuration
AWS.config.update({ region: CONFIG.region });
const costExplorer = new AWS.CostExplorer({ region: 'us-east-1' }); // Cost Explorer is only in us-east-1
const budgets = new AWS.Budgets();
const sns = new AWS.SNS();

/**
 * Get current month cost data
 */
async function getCurrentMonthCosts() {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const startOfNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  
  const params = {
    TimePeriod: {
      Start: startOfMonth.toISOString().split('T')[0],
      End: startOfNextMonth.toISOString().split('T')[0]
    },
    Granularity: 'MONTHLY',
    Metrics: ['BlendedCost'],
    GroupBy: [
      {
        Type: 'DIMENSION',
        Key: 'SERVICE'
      }
    ],
    Filter: {
      Dimensions: {
        Key: 'SERVICE',
        Values: CONFIG.services,
        MatchOptions: ['EQUALS']
      }
    }
  };
  
  try {
    const result = await costExplorer.getCostAndUsage(params).promise();
    return result.ResultsByTime[0] || { Groups: [] };
  } catch (error) {
    console.error('Error fetching cost data:', error.message);
    return { Groups: [] };
  }
}

/**
 * Get daily costs for the current month
 */
async function getDailyCosts() {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const today = new Date();
  
  const params = {
    TimePeriod: {
      Start: startOfMonth.toISOString().split('T')[0],
      End: today.toISOString().split('T')[0]
    },
    Granularity: 'DAILY',
    Metrics: ['BlendedCost'],
    Filter: {
      Dimensions: {
        Key: 'SERVICE',
        Values: CONFIG.services,
        MatchOptions: ['EQUALS']
      }
    }
  };
  
  try {
    const result = await costExplorer.getCostAndUsage(params).promise();
    return result.ResultsByTime || [];
  } catch (error) {
    console.error('Error fetching daily cost data:', error.message);
    return [];
  }
}

/**
 * Get cost forecast for the current month
 */
async function getCostForecast() {
  const now = new Date();
  const startOfNextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  const endOfNextMonth = new Date(now.getFullYear(), now.getMonth() + 2, 0);
  
  const params = {
    TimePeriod: {
      Start: startOfNextMonth.toISOString().split('T')[0],
      End: endOfNextMonth.toISOString().split('T')[0]
    },
    Metric: 'BLENDED_COST',
    Granularity: 'MONTHLY',
    Filter: {
      Dimensions: {
        Key: 'SERVICE',
        Values: CONFIG.services,
        MatchOptions: ['EQUALS']
      }
    }
  };
  
  try {
    const result = await costExplorer.getCostForecast(params).promise();
    return result;
  } catch (error) {
    console.error('Error fetching cost forecast:', error.message);
    return { ForecastResultsByTime: [] };
  }
}

/**
 * Get budget information
 */
async function getBudgetInfo() {
  const params = {
    AccountId: await getAccountId()
  };
  
  try {
    const result = await budgets.describeBudgets(params).promise();
    return result.Budgets.find(budget => 
      budget.BudgetName.includes(CONFIG.appName) || 
      budget.BudgetName.includes('monthly-budget')
    );
  } catch (error) {
    console.error('Error fetching budget info:', error.message);
    return null;
  }
}

/**
 * Get AWS Account ID
 */
async function getAccountId() {
  if (!CONFIG.accountId) {
    const sts = new AWS.STS();
    const result = await sts.getCallerIdentity().promise();
    CONFIG.accountId = result.Account;
  }
  return CONFIG.accountId;
}

/**
 * Generate cost report
 */
async function generateCostReport() {
  console.log('📊 Generating SlightBuild Cost Report...\n');
  
  try {
    const [currentCosts, dailyCosts, forecast, budget] = await Promise.all([
      getCurrentMonthCosts(),
      getDailyCosts(),
      getCostForecast(),
      getBudgetInfo()
    ]);
    
    // Calculate total current month cost
    const totalCost = currentCosts.Groups.reduce((sum, group) => {
      return sum + parseFloat(group.Metrics.BlendedCost.Amount);
    }, 0);
    
    // Generate report
    const report = {
      timestamp: new Date().toISOString(),
      period: new Date().toISOString().substring(0, 7), // YYYY-MM
      summary: {
        totalCost: totalCost.toFixed(2),
        budgetLimit: CONFIG.budgetLimit,
        budgetUsed: budget ? ((totalCost / CONFIG.budgetLimit) * 100).toFixed(1) : 'N/A',
        status: totalCost > CONFIG.budgetLimit * CONFIG.alertThreshold ? 'WARNING' : 'OK'
      },
      serviceBreakdown: currentCosts.Groups.map(group => ({
        service: group.Keys[0],
        cost: parseFloat(group.Metrics.BlendedCost.Amount).toFixed(2),
        percentage: ((parseFloat(group.Metrics.BlendedCost.Amount) / totalCost) * 100).toFixed(1)
      })),
      dailyTrend: dailyCosts.slice(-7).map(day => ({
        date: day.TimePeriod.Start,
        cost: parseFloat(day.Total.BlendedCost.Amount).toFixed(2)
      })),
      forecast: forecast.ForecastResultsByTime.length > 0 ? {
        nextMonth: parseFloat(forecast.ForecastResultsByTime[0].MeanValue).toFixed(2),
        confidence: 'Medium'
      } : null
    };
    
    // Display console report
    console.log('💰 COST SUMMARY');
    console.log('===============');
    console.log(`Current Month Cost: $${report.summary.totalCost}`);
    console.log(`Budget Limit: $${report.summary.budgetLimit}`);
    console.log(`Budget Used: ${report.summary.budgetUsed}%`);
    console.log(`Status: ${report.summary.status}`);
    console.log('');
    
    console.log('📋 SERVICE BREAKDOWN');
    console.log('====================');
    report.serviceBreakdown.forEach(service => {
      console.log(`${service.service.padEnd(25)} $${service.cost.padStart(6)} (${service.percentage}%)`);
    });
    console.log('');
    
    if (report.dailyTrend.length > 0) {
      console.log('📈 DAILY TREND (Last 7 Days)');
      console.log('============================');
      report.dailyTrend.forEach(day => {
        console.log(`${day.date} $${day.cost}`);
      });
      console.log('');
    }
    
    if (report.forecast) {
      console.log('🔮 FORECAST');
      console.log('===========');
      console.log(`Next Month Estimate: $${report.forecast.nextMonth}`);
      console.log('');
    }
    
    // Save report to file
    if (!fs.existsSync(CONFIG.outputDir)) {
      fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    }
    
    const reportFile = path.join(CONFIG.outputDir, `cost-report-${report.period}.json`);
    fs.writeFileSync(reportFile, JSON.stringify(report, null, 2));
    console.log(`📄 Report saved to: ${reportFile}`);
    
    return report;
    
  } catch (error) {
    console.error('❌ Error generating cost report:', error.message);
    process.exit(1);
  }
}

/**
 * Check for cost alerts
 */
async function checkCostAlerts() {
  console.log('🚨 Checking Cost Alerts...\n');
  
  try {
    const currentCosts = await getCurrentMonthCosts();
    const totalCost = currentCosts.Groups.reduce((sum, group) => {
      return sum + parseFloat(group.Metrics.BlendedCost.Amount);
    }, 0);
    
    const percentageUsed = (totalCost / CONFIG.budgetLimit) * 100;
    
    console.log(`Current cost: $${totalCost.toFixed(2)}`);
    console.log(`Budget limit: $${CONFIG.budgetLimit}`);
    console.log(`Percentage used: ${percentageUsed.toFixed(1)}%`);
    
    if (percentageUsed >= 100) {
      console.log('🔴 CRITICAL: Budget limit exceeded!');
      await sendAlert('CRITICAL', `Budget exceeded: $${totalCost.toFixed(2)} / $${CONFIG.budgetLimit}`);
    } else if (percentageUsed >= CONFIG.alertThreshold * 100) {
      console.log('🟡 WARNING: Approaching budget limit');
      await sendAlert('WARNING', `Budget ${percentageUsed.toFixed(1)}% used: $${totalCost.toFixed(2)} / $${CONFIG.budgetLimit}`);
    } else {
      console.log('✅ OK: Within budget limits');
    }
    
  } catch (error) {
    console.error('❌ Error checking cost alerts:', error.message);
    process.exit(1);
  }
}

/**
 * Send alert notification
 */
async function sendAlert(level, message) {
  const topicArn = process.env.SNS_ALERT_TOPIC;
  
  if (!topicArn) {
    console.log('⚠️  SNS_ALERT_TOPIC not configured, skipping notification');
    return;
  }
  
  const params = {
    TopicArn: topicArn,
    Subject: `SlightBuild Cost Alert - ${level}`,
    Message: `${message}\n\nTimestamp: ${new Date().toISOString()}\nApp: ${CONFIG.appName}`
  };
  
  try {
    await sns.publish(params).promise();
    console.log('📧 Alert notification sent');
  } catch (error) {
    console.error('❌ Error sending alert:', error.message);
  }
}

/**
 * Provide cost optimization recommendations
 */
async function generateOptimizationReport() {
  console.log('⚡ Generating Cost Optimization Recommendations...\n');
  
  try {
    const currentCosts = await getCurrentMonthCosts();
    const recommendations = [];
    
    currentCosts.Groups.forEach(group => {
      const service = group.Keys[0];
      const cost = parseFloat(group.Metrics.BlendedCost.Amount);
      
      switch (service) {
        case 'Amazon Amplify':
          if (cost > 2.0) {
            recommendations.push({
              service,
              cost: cost.toFixed(2),
              recommendation: 'Consider enabling performance mode and optimizing build times',
              impact: 'Medium',
              effort: 'Low'
            });
          }
          break;
          
        case 'Amazon CloudFront':
          if (cost > 1.0) {
            recommendations.push({
              service,
              cost: cost.toFixed(2),
              recommendation: 'Review caching policies and consider image optimization',
              impact: 'High',
              effort: 'Medium'
            });
          }
          break;
          
        case 'Amazon Route 53':
          if (cost > 1.0) {
            recommendations.push({
              service,
              cost: cost.toFixed(2),
              recommendation: 'Review DNS queries and consider consolidating hosted zones',
              impact: 'Low',
              effort: 'Low'
            });
          }
          break;
      }
    });
    
    console.log('💡 OPTIMIZATION RECOMMENDATIONS');
    console.log('================================');
    
    if (recommendations.length === 0) {
      console.log('✅ No specific recommendations - costs are optimized');
    } else {
      recommendations.forEach((rec, index) => {
        console.log(`${index + 1}. ${rec.service} ($${rec.cost})`);
        console.log(`   Recommendation: ${rec.recommendation}`);
        console.log(`   Impact: ${rec.impact} | Effort: ${rec.effort}`);
        console.log('');
      });
    }
    
    // General recommendations
    console.log('🎯 GENERAL BEST PRACTICES');
    console.log('=========================');
    console.log('• Enable Amplify performance mode for faster builds');
    console.log('• Use appropriate cache headers for static assets');
    console.log('• Monitor and clean up old build artifacts');
    console.log('• Set up budget alerts for proactive cost management');
    console.log('• Review and optimize image sizes and formats');
    console.log('• Consider using CDN edge locations closer to users');
    
  } catch (error) {
    console.error('❌ Error generating optimization report:', error.message);
    process.exit(1);
  }
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  
  try {
    if (args.includes('--report')) {
      await generateCostReport();
    } else if (args.includes('--alert')) {
      await checkCostAlerts();
    } else if (args.includes('--optimize')) {
      await generateOptimizationReport();
    } else {
      // Default: run all
      await generateCostReport();
      console.log('\n' + '='.repeat(50) + '\n');
      await checkCostAlerts();
      console.log('\n' + '='.repeat(50) + '\n');
      await generateOptimizationReport();
    }
  } catch (error) {
    console.error('❌ Script execution failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = {
  generateCostReport,
  checkCostAlerts,
  generateOptimizationReport
};