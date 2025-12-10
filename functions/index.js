/**
 * Firebase Cloud Function for verifying Google Play in-app purchases
 * 
 * Setup Instructions:
 * 1. Enable Google Play Developer API in Google Cloud Console
 * 2. Create a service account with permissions
 * 3. Download service account JSON key
 * 4. Add the key to Firebase Functions config
 * 5. Deploy this function
 * 
 * Usage:
 * Call this function from your Flutter app with the purchase token
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

// Google Play Developer API configuration
const PACKAGE_NAME = 'com.yourcompany.angelsjackpot'; // Replace with your package name
const PRODUCT_ID = 'remove_ads';

/**
 * Verify a Google Play in-app purchase
 * 
 * Request body:
 * {
 *   "purchaseToken": "string",
 *   "productId": "string",
 *   "userId": "string" (optional)
 * }
 */
exports.verifyPurchase = functions.https.onCall(async (data, context) => {
    try {
        const { purchaseToken, productId, userId } = data;

        // Validate input
        if (!purchaseToken || !productId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters'
            );
        }

        // Authenticate with Google Play Developer API
        const auth = new google.auth.GoogleAuth({
            keyFile: './service-account-key.json', // Path to your service account key
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });

        const androidPublisher = google.androidpublisher({
            version: 'v3',
            auth: auth,
        });

        // Verify the purchase with Google Play
        const response = await androidPublisher.purchases.products.get({
            packageName: PACKAGE_NAME,
            productId: productId,
            token: purchaseToken,
        });

        const purchase = response.data;

        // Check purchase state
        // 0 = Purchased, 1 = Canceled, 2 = Pending
        if (purchase.purchaseState !== 0) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Purchase is not in purchased state'
            );
        }

        // Check if purchase is consumed (for consumable products)
        // For non-consumable products like ad removal, this should be 0
        if (purchase.consumptionState === 1) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'Purchase has already been consumed'
            );
        }

        // Store purchase record in Firestore
        const purchaseRecord = {
            productId: productId,
            purchaseToken: purchaseToken,
            purchaseTime: purchase.purchaseTimeMillis,
            orderId: purchase.orderId,
            purchaseState: purchase.purchaseState,
            consumptionState: purchase.consumptionState,
            userId: userId || context.auth?.uid || 'anonymous',
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            platform: 'android',
        };

        // Save to Firestore
        await admin.firestore()
            .collection('purchases')
            .doc(purchase.orderId)
            .set(purchaseRecord, { merge: true });

        // Also update user's purchase status
        if (userId || context.auth?.uid) {
            const uid = userId || context.auth.uid;
            await admin.firestore()
                .collection('users')
                .doc(uid)
                .set({
                    purchases: {
                        [productId]: {
                            purchased: true,
                            orderId: purchase.orderId,
                            purchaseTime: purchase.purchaseTimeMillis,
                        }
                    }
                }, { merge: true });
        }

        return {
            success: true,
            verified: true,
            orderId: purchase.orderId,
            purchaseTime: purchase.purchaseTimeMillis,
        };

    } catch (error) {
        console.error('Error verifying purchase:', error);

        if (error.code && error.code.startsWith('functions/')) {
            throw error;
        }

        throw new functions.https.HttpsError(
            'internal',
            'Failed to verify purchase',
            error.message
        );
    }
});

/**
 * Verify an iOS App Store purchase
 * 
 * Request body:
 * {
 *   "receiptData": "string",
 *   "productId": "string",
 *   "userId": "string" (optional)
 * }
 */
exports.verifyAppleReceipt = functions.https.onCall(async (data, context) => {
    try {
        const { receiptData, productId, userId } = data;

        if (!receiptData || !productId) {
            throw new functions.https.HttpsError(
                'invalid-argument',
                'Missing required parameters'
            );
        }

        // Verify with App Store
        // First try production, then sandbox if that fails
        let verificationResult = await verifyWithAppStore(receiptData, false);

        // If production fails with 21007 (sandbox receipt), try sandbox
        if (verificationResult.status === 21007) {
            verificationResult = await verifyWithAppStore(receiptData, true);
        }

        if (verificationResult.status !== 0) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                `App Store verification failed with status: ${verificationResult.status}`
            );
        }

        // Extract purchase info
        const receipt = verificationResult.receipt;
        const inAppPurchases = receipt.in_app || [];

        // Find the specific product
        const purchase = inAppPurchases.find(p => p.product_id === productId);

        if (!purchase) {
            throw new functions.https.HttpsError(
                'not-found',
                'Product not found in receipt'
            );
        }

        // Store purchase record
        const purchaseRecord = {
            productId: productId,
            transactionId: purchase.transaction_id,
            originalTransactionId: purchase.original_transaction_id,
            purchaseDate: purchase.purchase_date_ms,
            userId: userId || context.auth?.uid || 'anonymous',
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            platform: 'ios',
        };

        await admin.firestore()
            .collection('purchases')
            .doc(purchase.transaction_id)
            .set(purchaseRecord, { merge: true });

        // Update user's purchase status
        if (userId || context.auth?.uid) {
            const uid = userId || context.auth.uid;
            await admin.firestore()
                .collection('users')
                .doc(uid)
                .set({
                    purchases: {
                        [productId]: {
                            purchased: true,
                            transactionId: purchase.transaction_id,
                            purchaseDate: purchase.purchase_date_ms,
                        }
                    }
                }, { merge: true });
        }

        return {
            success: true,
            verified: true,
            transactionId: purchase.transaction_id,
            purchaseDate: purchase.purchase_date_ms,
        };

    } catch (error) {
        console.error('Error verifying Apple receipt:', error);

        if (error.code && error.code.startsWith('functions/')) {
            throw error;
        }

        throw new functions.https.HttpsError(
            'internal',
            'Failed to verify receipt',
            error.message
        );
    }
});

/**
 * Helper function to verify receipt with App Store
 */
async function verifyWithAppStore(receiptData, sandbox = false) {
    const https = require('https');

    const url = sandbox
        ? 'https://sandbox.itunes.apple.com/verifyReceipt'
        : 'https://buy.itunes.apple.com/verifyReceipt';

    const requestData = JSON.stringify({
        'receipt-data': receiptData,
        'password': functions.config().appstore?.shared_secret || '', // Set via Firebase config
    });

    return new Promise((resolve, reject) => {
        const options = {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': requestData.length,
            },
        };

        const req = https.request(url, options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                try {
                    resolve(JSON.parse(data));
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', reject);
        req.write(requestData);
        req.end();
    });
}
