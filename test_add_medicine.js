// Test script for Add Medicine functionality
// Run this in Chrome console after navigating to pharmacy dashboard

// Test data for adding medicine
const testMedicine = {
  name: 'Test Medicine 500mg',
  category: 'Antibiotics',
  quantity: 100,
  unitPrice: 15.50,
  expiryDate: new Date('2025-12-31'),
  batchNumber: 'TEST2024001',
  supplier: 'Test Supplier Co.',
  minStock: 20,
  dosage: '1 tablet 3x daily',
  instructions: 'Take with food'
};

console.log('Test medicine data:', testMedicine);
console.log('Ready to test add medicine form');